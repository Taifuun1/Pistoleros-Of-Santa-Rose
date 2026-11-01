extends RefCounted
class_name OverworldMapBaker

## Pure full-world semantic bake (Docs/System Design/Journal/Overworld
## Map.md): a typed style grid over the declared cell rectangle, exactly one
## lossless working pixel per cell, then a deterministic vertical downsample.
## Takes decoded chunk data (real or synthetic); scene loading, saving and
## command-line behavior live in Tools/GenerateOverworldMap.gd so tests can
## bake synthetic worlds without touching real chunks.

var coordinates: OverworldCoordinates
var projection: OverworldMapProjection
var chunkGrid: Rect2i
var chunkTiles: Vector2i


func _init(mapCoordinates: OverworldCoordinates, mapProjection: OverworldMapProjection, grid: Rect2i, tiles: Vector2i) -> void:
	coordinates = mapCoordinates
	projection = mapProjection
	chunkGrid = grid
	chunkTiles = tiles


## chunkCells: chunk -> PackedInt32Array (reader six-int records);
## chunkScripts: chunk -> { "locations": Dictionary, "spawnPoints": Dictionary }.
## Returns { "image": Image (final), "locations": Array (normalized),
## "report": Dictionary } plus "overview": Image when lodBlock is non-zero.
## report["errors"] being non-empty makes the bake invalid (out-of-grid cells,
## invalid Location anchors). Missing chunks stay transparent and are only
## reported. Cells written by more than one chunk (authoring overlaps across
## seams) are reported in "overlappingCells" and resolved deterministically —
## the later chunk in sorted (x, y) order wins — instead of failing; the current
## world data carries a few of these.
func bake(chunkCells: Dictionary, chunkScripts: Dictionary, styles: MapTileStyles, lodBlock: Vector2i = Vector2i.ZERO) -> Dictionary:
	var report := {
		"presentChunks": [], "missingChunks": [], "cells": 0,
		"unknownStyles": {}, "overlappingCells": [], "outOfGridCells": [], "sharedLocationIds": {}, "errors": [],
	}
	var gridWidth := projection.cellMax.x - projection.cellMin.x + 1
	var gridHeight := projection.cellMax.y - projection.cellMin.y + 1
	var styleGrid := PackedInt32Array()
	styleGrid.resize(gridWidth * gridHeight)

	for chunkX in range(chunkGrid.position.x, chunkGrid.position.x + chunkGrid.size.x):
		for chunkY in range(chunkGrid.position.y, chunkGrid.position.y + chunkGrid.size.y):
			var chunk := Vector2i(chunkX, chunkY)
			if !chunkCells.has(chunk):
				report["missingChunks"].append(chunk)
				continue
			report["presentChunks"].append(chunk)
			_readChunkCells(chunk, chunkCells[chunk], styles, styleGrid, gridWidth, report)

	var locations := _collectLocations(chunkScripts, report)
	var image := _rasterize(styleGrid, gridWidth, styles)
	var result := { "image": image, "locations": locations, "report": report }
	if lodBlock.x > 0 and lodBlock.y > 0:
		result["overview"] = _aggregate(styleGrid, gridWidth, styles, lodBlock)
	return result

## Overview/LOD aggregation (Docs/System Design/Journal/Overworld Map.md): one
## output pixel per lodBlock cells. Thin, absolute features (water, track,
## powerline) win their block with any presence, so rivers and lines survive
## generalization; area features (forest, swamp, mountain, cliff, structure)
## need LOD_AREA_SHARE of the block, so scattered foliage does not flood the
## plains. Among qualifying features the higher style priority wins (cliff over
## forest, structure over everything), and the block's most common style within
## that feature supplies the color. Blocks that are mostly empty stay
## transparent so missing chunks keep their shape.
const LOD_MIN_FILL_SHARE := 0.25
const LOD_AREA_SHARE := 0.3
const LOD_LINEAR_FEATURES := [
	MapTileStyles.FEATURE_WATER,
	MapTileStyles.FEATURE_TRACK,
	MapTileStyles.FEATURE_POWERLINE,
]


func _aggregate(styleGrid: PackedInt32Array, gridWidth: int, styles: MapTileStyles, lodBlock: Vector2i) -> Image:
	var gridHeight := styleGrid.size() / gridWidth
	var outWidth := ceili(float(gridWidth) / float(lodBlock.x))
	var outHeight := ceili(float(gridHeight) / float(lodBlock.y))
	var pixels := PackedByteArray()
	pixels.resize(outWidth * outHeight * 4)
	var minFilled := int(ceil(float(lodBlock.x * lodBlock.y) * LOD_MIN_FILL_SHARE))
	for blockY in outHeight:
		for blockX in outWidth:
			var featureCells := {}
			var featureStyles := {}
			var filled := 0
			for y in range(blockY * lodBlock.y, mini((blockY + 1) * lodBlock.y, gridHeight)):
				for x in range(blockX * lodBlock.x, mini((blockX + 1) * lodBlock.x, gridWidth)):
					var stored := styleGrid[y * gridWidth + x]
					if stored == 0:
						continue
					var styleId := stored - 1
					filled += 1
					var feature: String = styles.styleForId(styleId)["feature"]
					featureCells[feature] = int(featureCells.get(feature, 0)) + 1
					var perFeature: Dictionary = featureStyles.get(feature, {})
					perFeature[styleId] = int(perFeature.get(styleId, 0)) + 1
					featureStyles[feature] = perFeature
			if filled < minFilled:
				continue
			var bestFeature := ""
			var bestPriority := -1
			var bestShare := -1.0
			var features: Array = featureCells.keys()
			features.sort()
			for feature in features:
				var share := float(featureCells[feature]) / float(filled)
				var isLinear: bool = feature in LOD_LINEAR_FEATURES
				if !isLinear and feature != MapTileStyles.FEATURE_GROUND and share < LOD_AREA_SHARE:
					continue
				var priority: int = int(styles.styleForId(_mostCommonStyle(featureStyles[feature]))["priority"])
				if priority > bestPriority or (priority == bestPriority and share > bestShare):
					bestPriority = priority
					bestShare = share
					bestFeature = feature
			var color: Color = styles.styleForId(_mostCommonStyle(featureStyles[bestFeature]))["color"]
			var offset := (blockY * outWidth + blockX) * 4
			pixels[offset] = color.r8
			pixels[offset + 1] = color.g8
			pixels[offset + 2] = color.b8
			pixels[offset + 3] = color.a8
	return Image.create_from_data(outWidth, outHeight, false, Image.FORMAT_RGBA8, pixels)


## Most common style id in a { styleId: count } tally; ties break to the lowest
## id so the result never depends on Dictionary order.
func _mostCommonStyle(counts: Dictionary) -> int:
	var winner := 0
	var best := -1
	var ids: Array = counts.keys()
	ids.sort()
	for styleId in ids:
		if int(counts[styleId]) > best:
			best = int(counts[styleId])
			winner = styleId
	return winner




func _readChunkCells(chunk: Vector2i, cells: PackedInt32Array, styles: MapTileStyles, styleGrid: PackedInt32Array, gridWidth: int, report: Dictionary) -> void:
	var index := 0
	while index < cells.size():
		var cell := Vector2i(cells[index], cells[index + 1])
		if !projection.hasCell(cell):
			report["outOfGridCells"].append([chunk, cell])
			report["errors"].append("chunk {chunk} writes cell {cell} outside the declared grid".format({ "chunk": chunk, "cell": cell }))
		else:
			var key := Vector3i(cells[index + 2], cells[index + 3], cells[index + 4])
			var styleId := styles.styleIdFor(key.x, key.y, key.z)
			if styleId == 0:
				report["unknownStyles"][key] = int(report["unknownStyles"].get(key, 0)) + 1
			var gridIndex := (cell.x - projection.cellMin.x) + (cell.y - projection.cellMin.y) * gridWidth
			if styleGrid[gridIndex] != 0:
				report["overlappingCells"].append([chunk, cell])
			else:
				report["cells"] += 1
			styleGrid[gridIndex] = styleId + 1
		index += 6


## Location anchors normalized to shared cells and image coordinates, keeping
## chunk + tile for diagnostics. Locations declared by several chunks (the
## world shares one script per chunk a location spans, e.g. Donnafolk Caves)
## dedupe to the first anchor in sorted chunk order and are reported in
## "sharedLocationIds"; empty tile lists are errors, never silently repaired.
func _collectLocations(chunkScripts: Dictionary, report: Dictionary) -> Array:
	var locations := []
	var seenIds := {}
	var chunks: Array = chunkScripts.keys()
	chunks.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	for chunk in chunks:
		var scriptData: Dictionary = chunkScripts[chunk]
		var names: Array = scriptData.get("locations", {}).keys()
		names.sort()
		for locationName in names:
			if seenIds.has(locationName):
				if !report["sharedLocationIds"].has(locationName):
					report["sharedLocationIds"][locationName] = [seenIds[locationName]]
				report["sharedLocationIds"][locationName].append(chunk)
				continue
			seenIds[locationName] = chunk
			var entry: Dictionary = scriptData["locations"][locationName]
			var tiles = entry.get("tiles", [])
			if tiles.is_empty():
				report["errors"].append("location '{name}' (chunk {chunk}) has no anchor tile".format({ "name": locationName, "chunk": chunk }))
				continue
			var anchorTile: Vector2i = tiles[0]
			var cell := coordinates.chunkTileToCell(chunk, anchorTile)
			locations.append({
				"id": locationName,
				"display_name": locationName,
				"chunk": chunk,
				"tile": anchorTile,
				"cell": cell,
				"image_position": projection.cellToImage(cell),
				"icon": "location",
			})
	return locations


## Each present cell paints the projection's working footprint — the isometric
## lattice pixel plus its parity hole, or the aligned cell block — so the
## working surface tiles densely, then the projection's downsample produces the
## final image (a vertical 1/2 bilinear resize when isometric). No viewport
## drawing, no texture sampling.
func _rasterize(styleGrid: PackedInt32Array, gridWidth: int, styles: MapTileStyles) -> Image:
	var width := projection.workingSize.x
	var height := projection.workingSize.y
	var footprint := projection.workingCellFootprint
	var colors := PackedByteArray()
	colors.resize((styles.styleCount() + 2) * 4)
	_storeColor(colors, 0, Color(0, 0, 0, 0))
	_storeColor(colors, 4, MapTileStyles.UNKNOWN_STYLE["color"])
	for styleId in range(1, styles.styleCount() + 1):
		_storeColor(colors, (styleId + 1) * 4, styles.styleForId(styleId)["color"])

	var pixels := PackedByteArray()
	pixels.resize(width * height * 4)
	for gridIndex in styleGrid.size():
		var value := styleGrid[gridIndex]
		if value == 0:
			continue
		var cell := Vector2i(
			projection.cellMin.x + gridIndex % gridWidth,
			projection.cellMin.y + gridIndex / gridWidth
		)
		var workingPixel := projection.cellToWorkingPixel(cell)
		var colorIndex := value * 4
		for footprintY in footprint.y:
			var rowIndex := (workingPixel.y + footprintY) * width + workingPixel.x
			for footprintX in footprint.x:
				var offset := (rowIndex + footprintX) * 4
				pixels[offset] = colors[colorIndex]
				pixels[offset + 1] = colors[colorIndex + 1]
				pixels[offset + 2] = colors[colorIndex + 2]
				pixels[offset + 3] = colors[colorIndex + 3]
	var working := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, pixels)
	if projection.downsample != Vector2i.ONE:
		working.resize(projection.imageSize.x, projection.imageSize.y, Image.INTERPOLATE_BILINEAR)
	return working


func _storeColor(colors: PackedByteArray, offset: int, color: Color) -> void:
	colors[offset] = int(round(color.r8))
	colors[offset + 1] = int(round(color.g8))
	colors[offset + 2] = int(round(color.b8))
	colors[offset + 3] = int(round(color.a8))