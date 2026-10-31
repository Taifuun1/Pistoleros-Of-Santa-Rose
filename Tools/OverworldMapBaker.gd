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
## "report": Dictionary }; report["errors"] being non-empty makes the bake
## invalid (out-of-grid cells, invalid Location anchors). Missing chunks stay
## transparent and are only reported. Cells written by more than one chunk
## (authoring overlaps across seams) are reported in "overlappingCells" and
## resolved deterministically — the later chunk in sorted (x, y) order wins —
## instead of failing; the current world data carries a few of these.
func bake(chunkCells: Dictionary, chunkScripts: Dictionary, styles: MapTileStyles) -> Dictionary:
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
	return { "image": image, "locations": locations, "report": report }


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


## Each present cell paints a 2x1 footprint — its lattice pixel (u - v, u + v)
## plus the (x + 1, y) parity hole, which no other cell's lattice pixel can
## claim — so the working surface tiles densely with no transparent
## every-other-column stripes, then a vertical 1/2 bilinear downsample produces
## the final image. No viewport drawing, no texture sampling.
func _rasterize(styleGrid: PackedInt32Array, gridWidth: int, styles: MapTileStyles) -> Image:
	var width := projection.workingSize.x
	var height := projection.workingSize.y
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
		var pixelIndex := (workingPixel.y * width + workingPixel.x) * 4
		var colorIndex := value * 4
		for offset in [pixelIndex, pixelIndex + 4]:
			pixels[offset] = colors[colorIndex]
			pixels[offset + 1] = colors[colorIndex + 1]
			pixels[offset + 2] = colors[colorIndex + 2]
			pixels[offset + 3] = colors[colorIndex + 3]
	var working := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, pixels)
	working.resize(width, ceili(float(height) * 0.5), Image.INTERPOLATE_BILINEAR)
	return working


func _storeColor(colors: PackedByteArray, offset: int, color: Color) -> void:
	colors[offset] = int(round(color.r8))
	colors[offset + 1] = int(round(color.g8))
	colors[offset + 2] = int(round(color.b8))
	colors[offset + 3] = int(round(color.a8))