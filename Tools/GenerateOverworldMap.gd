extends SceneTree

## Headless full-world map bake/report tool (Docs/System Design/Journal/
## Overworld Map.md, implementation steps 3-4). Bakes the checked-in
## Assets/Journal/OverworldMap.png and Data/Overworld/OverworldMapData.tres
## from every declared chunk through the shared reader/coordinates/
## projection; the game never runs this at runtime.
##
##   godot --headless --path . --script res://Tools/GenerateOverworldMap.gd
##   ... -- --survey            print the encountered tile-key palette survey
##   ... -- --check             fail when the committed PNG/manifest is stale
##   ... -- --require-complete  fail when any declared chunk is missing
##   ... -- --strict            fail on unstyled tile keys / overlapping cells
##
## Deterministic: sorted chunk/style/POI order, outputs written only when
## their bytes/values changed. The source fingerprint covers sorted chunk
## scenes (including missing ones), their chunk scripts, the shared tileset,
## world/style data and the shared coordinate/reader/projection/baker code;
## dynamic player/quest state is deliberately absent.

const HelperVariablesScript := preload("res://Globals/HelperVariables.gd")
const OUTPUT_PNG := "res://Assets/Journal/OverworldMap.png"
const OUTPUT_DATA := "res://Data/Overworld/OverworldMapData.tres"
const FINGERPRINT_CODE_PATHS := [
	"res://Data/Overworld/WorldData.gd",
	"res://Data/Overworld/MapTileStyles.gd",
	"res://Overworld/OverworldCoordinates.gd",
	"res://Overworld/OverworldChunkReader.gd",
	"res://Overworld/OverworldMapProjection.gd",
	"res://Tools/OverworldMapBaker.gd",
]

var _survey := false
var _strict := false
var _check := false
var _requireComplete := false


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		match argument:
			"--survey":
				_survey = true
			"--require-complete":
				_requireComplete = true
			"--strict":
				_strict = true
			"--check":
				_check = true
			_:
				push_warning("GenerateOverworldMap: unknown argument '{argument}'".format({ "argument": argument }))
	call_deferred("_run")


func _run() -> void:
	var helperVars = HelperVariablesScript.new()
	var chunkTiles: Vector2i = helperVars.overworldChunkSize
	helperVars.free()

	var coordinates := OverworldCoordinates.makeHeadless()
	var mapProjection := OverworldMapProjection.cellForGrid(coordinates, WorldData.CHUNK_GRID, chunkTiles)
	var reader := OverworldChunkReader.new(coordinates)

	var chunkCells := {}
	var chunkScripts := {}
	var chunkScriptPaths := {}
	var missingChunks: Array = []
	var failedChunks: Array = []
	for chunkX in range(WorldData.CHUNK_GRID.position.x, WorldData.CHUNK_GRID.position.x + WorldData.CHUNK_GRID.size.x):
		for chunkY in range(WorldData.CHUNK_GRID.position.y, WorldData.CHUNK_GRID.position.y + WorldData.CHUNK_GRID.size.y):
			var chunk := Vector2i(chunkX, chunkY)
			if !WorldData.hasChunkScene(chunk):
				missingChunks.append(chunk)
				continue
			# One chunk at a time, sorted (x, y); the scene reference is
			# dropped before the next load.
			var packedScene: PackedScene = load(WorldData.getChunkPath(chunk))
			var chunkScript := OverworldChunkReader.getChunkScript(packedScene)
			if chunkScript != null:
				chunkScriptPaths[chunkScript.resource_path] = true
			var chunkRead := reader.readChunk(chunk, packedScene)
			packedScene = null
			if !chunkRead["errors"].is_empty():
				failedChunks.append([chunk, chunkRead["errors"]])
				continue
			chunkCells[chunk] = chunkRead["cells"]
			chunkScripts[chunk] = { "locations": chunkRead["locations"], "spawnPoints": chunkRead["spawnPoints"] }

	if _survey:
		_surveyPalette(chunkCells, missingChunks)
		quit(0)
		return

	var styles := MapTileStyles.new()
	var baker := OverworldMapBaker.new(coordinates, mapProjection, WorldData.CHUNK_GRID, chunkTiles)
	var baked := baker.bake(chunkCells, chunkScripts, styles)
	var report: Dictionary = baked["report"]

	print("GenerateOverworldMap report")
	print("  chunks: {present} present, {missing} missing, {failed} failed".format({
		"present": report["presentChunks"].size(),
		"missing": report["missingChunks"].size(),
		"failed": failedChunks.size(),
	}))
	if !missingChunks.is_empty():
		print("  missing chunks: ", missingChunks)
	for failed in failedChunks:
		printerr("  decode failed: ", failed[0], " ", failed[1])
	print("  cells: ", report["cells"])
	print("  overlapping seam cells: ", report["overlappingCells"].size(), " (later chunk in sorted order wins; --strict fails on these)")
	print("  out-of-grid cells: ", report["outOfGridCells"].size())
	var unknownKeys: Array = report["unknownStyles"].keys()
	if !unknownKeys.is_empty():
		unknownKeys.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y) or (a.x == b.x and a.y == b.y and a.z < b.z))
		print("  unknown styles: ", unknownKeys.size())
		for key in unknownKeys:
			printerr("    {key} x{count} (no MapTileStyles entry)".format({ "key": key, "count": report["unknownStyles"][key] }))
	print("  locations: ", baked["locations"].size())
	for sharedId in report["sharedLocationIds"]:
		printerr("  location '{id}' is declared by several chunks {chunks}; using the first".format({ "id": sharedId, "chunks": report["sharedLocationIds"][sharedId] }))
	for location in baked["locations"]:
		print("    {id} chunk={chunk} tile={tile} cell={cell} image={image}".format({
			"id": location["id"], "chunk": location["chunk"], "tile": location["tile"],
			"cell": location["cell"], "image": location["image_position"],
		}))
	print("  cell bounds: min={min} max={max}".format({ "min": mapProjection.cellMin, "max": mapProjection.cellMax }))
	print("  working image: {working}, final image: {final}, map origin: {origin}".format({
		"working": mapProjection.workingSize, "final": baked["image"].get_size(), "origin": mapProjection.mapOrigin,
	}))

	var exitCode := 0
	if !failedChunks.is_empty() or !report["errors"].is_empty():
		for reportError in report["errors"]:
			printerr("  bake error: ", reportError)
		exitCode = 1
	if _requireComplete and !missingChunks.is_empty():
		printerr("  --require-complete: {count} declared chunks are missing".format({ "count": missingChunks.size() }))
		exitCode = 1
	if _strict:
		if !unknownKeys.is_empty():
			printerr("  --strict: {count} tile keys have no authored style".format({ "count": unknownKeys.size() }))
			exitCode = 1
		if !report["overlappingCells"].is_empty():
			printerr("  --strict: {count} cells are written by more than one chunk".format({ "count": report["overlappingCells"].size() }))
			exitCode = 1

	if exitCode == 0 and _check:
		if !_checkOutputs(baked, mapProjection, missingChunks, chunkScriptPaths):
			exitCode = 1
	elif exitCode == 0:
		var pngStatus := _savePng(baked["image"])
		var manifest := _buildManifest(baked["image"], baked["locations"], mapProjection, missingChunks, chunkScriptPaths)
		var dataStatus := _saveData(manifest)
		print("  outputs: ", OUTPUT_PNG, " (", pngStatus, "), ", OUTPUT_DATA, " (", dataStatus, ")")
		if pngStatus == "error" or dataStatus == "error":
			exitCode = 1
	quit(exitCode)


## True when the committed PNG and manifest match a fresh in-memory bake,
## so manual edits to the generated outputs are detected too.
func _checkOutputs(baked: Dictionary, mapProjection: OverworldMapProjection, missingChunks: Array, chunkScriptPaths: Dictionary) -> bool:
	var pngCurrent: bool = FileAccess.get_file_as_bytes(OUTPUT_PNG) == baked["image"].save_png_to_buffer()
	var manifest := _buildManifest(baked["image"], baked["locations"], mapProjection, missingChunks, chunkScriptPaths)
	var manifestCurrent := false
	if ResourceLoader.exists(OUTPUT_DATA):
		var committed = load(OUTPUT_DATA)
		if committed != null and committed is OverworldMapData:
			manifestCurrent = manifest.matches(committed) and committed.texture != null
	if !pngCurrent:
		printerr("  --check: the committed PNG differs from a fresh bake (regenerate, or revert manual edits)")
	if !manifestCurrent:
		printerr("  --check: the committed manifest is missing, unreadable or stale (regenerate it)")
	if pngCurrent and manifestCurrent:
		print("  --check: committed outputs are current")
	return pngCurrent and manifestCurrent


func _buildManifest(image: Image, bakedLocations: Array, mapProjection: OverworldMapProjection, missingChunks: Array, chunkScriptPaths: Dictionary) -> OverworldMapData:
	var manifest := OverworldMapData.new()
	manifest.texture = load(OUTPUT_PNG)
	manifest.image_size = image.get_size()
	manifest.map_origin = mapProjection.mapOrigin
	manifest.pixels_per_cell = Vector2(1.0, 0.5)
	manifest.chunk_grid = WorldData.CHUNK_GRID
	manifest.cell_min = mapProjection.cellMin
	manifest.cell_max = mapProjection.cellMax
	manifest.source_fingerprint = _buildFingerprint(missingChunks, chunkScriptPaths)
	for location in bakedLocations:
		manifest.locations.append(location)
	return manifest


## Deterministic source fingerprint: shared bake code, the shared tileset,
## every declared chunk scene in sorted (x, y) order (missing ones included,
## so additions/deletions count), and every referenced chunk data script.
func _buildFingerprint(missingChunks: Array, chunkScriptPaths: Dictionary) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_MD5)
	for codePath in FINGERPRINT_CODE_PATHS:
		context.update((codePath + " " + FileAccess.get_md5(codePath) + "\n").to_utf8_buffer())
	context.update((WorldData.TEMPLATE_TILESET_PATH + " " + FileAccess.get_md5(WorldData.TEMPLATE_TILESET_PATH) + "\n").to_utf8_buffer())
	for chunkY in range(WorldData.CHUNK_GRID.position.y, WorldData.CHUNK_GRID.position.y + WorldData.CHUNK_GRID.size.y):
		for chunkX in range(WorldData.CHUNK_GRID.position.x, WorldData.CHUNK_GRID.position.x + WorldData.CHUNK_GRID.size.x):
			var chunk := Vector2i(chunkX, chunkY)
			var entry := "chunk {chunk} ".format({ "chunk": chunk })
			if missingChunks.has(chunk):
				entry += "missing"
			else:
				entry += FileAccess.get_md5(WorldData.getChunkPath(chunk))
			context.update((entry + "\n").to_utf8_buffer())
	var scriptPaths: Array = chunkScriptPaths.keys()
	scriptPaths.sort()
	for scriptPath in scriptPaths:
		context.update((scriptPath + " " + FileAccess.get_md5(scriptPath) + "\n").to_utf8_buffer())
	return context.finish().hex_encode()


## Writes the manifest only when its values changed.
func _saveData(manifest: OverworldMapData) -> String:
	if ResourceLoader.exists(OUTPUT_DATA):
		var committed = load(OUTPUT_DATA)
		if committed != null and committed is OverworldMapData and manifest.matches(committed):
			return "unchanged"
	var saveError := ResourceSaver.save(manifest, OUTPUT_DATA)
	if saveError != OK:
		printerr("  could not write ", OUTPUT_DATA, " (error ", saveError, ")")
		return "error"
	return "written"


## Writes the PNG only when its bytes changed, so unchanged bakes leave the
## checked-in output (and its import metadata) untouched.
func _savePng(image: Image) -> String:
	var pngBytes := image.save_png_to_buffer()
	if FileAccess.get_file_as_bytes(OUTPUT_PNG) == pngBytes:
		return "unchanged"
	var file := FileAccess.open(OUTPUT_PNG, FileAccess.WRITE)
	if file == null:
		printerr("  could not write ", OUTPUT_PNG)
		return "error"
	file.store_buffer(pngBytes)
	file.close()
	return "written"


## Palette survey: every (sourceId, atlasX, atlasY) key encountered in the
## chunks, with per-source names, tileset terrain tags, and prototype colors
## sampled from each atlas tile's ground band (bottom 24x12 rows, falling
## back to the top rows and then the source's dominant ground). Prints a
## ready-to-paste MapTileStyles STYLES table; averaging is a prototype aid,
## never final semantics (see the map doc's styling rules).
func _surveyPalette(chunkCells: Dictionary, missingChunks: Array) -> void:
	var counts := {}
	var alternatives := {}
	for chunk in chunkCells:
		var cells: PackedInt32Array = chunkCells[chunk]
		var index := 0
		while index < cells.size():
			var key := Vector3i(cells[index + 2], cells[index + 3], cells[index + 4])
			counts[key] = int(counts.get(key, 0)) + 1
			if cells[index + 5] != 0:
				alternatives[key] = cells[index + 5]
			index += 6

	var tileSet: TileSet = load(WorldData.TEMPLATE_TILESET_PATH)
	var terrainTags := _collectTerrainTags(tileSet)
	var sourceNames := {}
	var sourceImages := {}
	for sourceIndex in tileSet.get_source_count():
		var sourceId: int = tileSet.get_source_id(sourceIndex)
		var source: TileSetAtlasSource = tileSet.get_source(sourceId)
		sourceNames[sourceId] = source.resource_name
		sourceImages[sourceId] = source.texture.get_image()

	# Per-key prototype ground colors; two passes so tiles without usable
	# ground pixels (overlays/props) fall back to their source's ground.
	var candidates := {}
	var sourceGroundTotals := {}
	var sourceGroundCounts := {}
	for key in counts.keys():
		var sample := _sampleGroundColor(sourceImages[key.x], Vector2i(key.y, key.z))
		if sample[1] >= 0.35:
			candidates[key] = sample[0]
			if !sourceGroundTotals.has(key.x):
				sourceGroundTotals[key.x] = Color(0, 0, 0, 0)
				sourceGroundCounts[key.x] = 0
			sourceGroundTotals[key.x] += sample[0]
			sourceGroundCounts[key.x] += 1
	var sourceGround := {}
	for sourceId in sourceGroundTotals.keys():
		sourceGround[sourceId] = sourceGroundTotals[sourceId] / float(maxi(1, sourceGroundCounts[sourceId]))

	var keys: Array = counts.keys()
	keys.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y) or (a.x == b.x and a.y == b.y and a.z < b.z))

	print("GenerateOverworldMap survey")
	print("  chunks: {present} present, {missing} missing".format({ "present": chunkCells.size(), "missing": missingChunks.size() }))
	print("  distinct tile keys: ", keys.size())
	print("  sources:")
	for sourceId in sourceNames.keys():
		print("    {id}: {name} (ground fallback #{color})".format({
			"id": sourceId, "name": sourceNames[sourceId],
			"color": sourceGround.get(sourceId, Color(0, 0, 0, 0)).to_html(false),
		}))
	if !alternatives.is_empty():
		printerr("  non-zero alternatives encountered (not styled yet): ", alternatives)
	print("\n## Paste into Data/Overworld/MapTileStyles.gd -> STYLES:")
	for key in keys:
		var color: Color = candidates.get(key, sourceGround.get(key.x, Color(0.5, 0.5, 0.5)))
		var feature: String = terrainTags.get(key, MapTileStyles.FEATURE_GROUND)
		var priority := 10
		if feature == MapTileStyles.FEATURE_WATER:
			priority = 20
		elif feature == MapTileStyles.FEATURE_ROAD:
			priority = 25
		elif feature == MapTileStyles.FEATURE_STRUCTURE:
			priority = 30
		print("\tVector3i(%d, %d, %d): { \"color\": Color(\"#%s\"), \"feature\": \"%s\", \"priority\": %d }, # x%d %s" % [
			key.x, key.y, key.z, color.to_html(false), feature, priority, counts[key], sourceNames.get(key.x, "?"),
		])


## Maps atlas keys to map features via the tileset's terrain sets (Godot
## 4.7 exposes these as properties rather than the older indexed getters).
## Terrain and walkability stay separate concerns; only the map
## representation (water/road/structure emphasis) is derived here.
func _collectTerrainTags(tileSet: TileSet) -> Dictionary:
	var tags := {}
	var setFeatures := {}
	for setIndex in tileSet.get_terrain_sets_count():
		for terrainIndex in range(32):
			var terrainName = tileSet.get("terrain_set_{set}/terrain_{terrain}/name".format({ "set": setIndex, "terrain": terrainIndex }))
			if terrainName == null:
				break
			var feature := MapTileStyles.FEATURE_STRUCTURE
			var lowered: String = String(terrainName).to_lower()
			if lowered.contains("water"):
				feature = MapTileStyles.FEATURE_WATER
			elif lowered.contains("track") or lowered.contains("road"):
				feature = MapTileStyles.FEATURE_ROAD
			setFeatures[[setIndex, terrainIndex]] = feature
	for sourceIndex in tileSet.get_source_count():
		var sourceId: int = tileSet.get_source_id(sourceIndex)
		var source: TileSetAtlasSource = tileSet.get_source(sourceId)
		var gridSize: Vector2i = source.get_atlas_grid_size()
		for atlasY in gridSize.y:
			for atlasX in gridSize.x:
				if !source.has_tile(Vector2i(atlasX, atlasY)):
					continue
				var tileData: TileData = source.get_tile_data(Vector2i(atlasX, atlasY), 0)
				var terrainSet := tileData.get_terrain_set()
				if terrainSet < 0:
					continue
				var terrainKey := [terrainSet, tileData.get_terrain()]
				if setFeatures.has(terrainKey):
					tags[Vector3i(sourceId, atlasX, atlasY)] = setFeatures[terrainKey]
	return tags


## Average of the opaque pixels in a 24x48 atlas region's ground band: the
## bottom 24x12 rows first, then the top rows. Returns [color, coverage].
func _sampleGroundColor(atlasImage: Image, atlasCoords: Vector2i) -> Array:
	var grid := atlasImage.get_size() / Vector2i(24, 48)
	if atlasCoords.x < 0 or atlasCoords.y < 0 or atlasCoords.x >= grid.x or atlasCoords.y >= grid.y:
		return [Color(0, 0, 0, 0), 0.0]
	var origin := atlasCoords * Vector2i(24, 48)
	for band in [[36, 48], [0, 12]]:
		var total := Color(0, 0, 0, 0)
		var opaque := 0
		for y in range(band[0], band[1]):
			for x in range(24):
				var pixel := atlasImage.get_pixel(origin.x + x, origin.y + y)
				if pixel.a > 0.5:
					total += pixel
					opaque += 1
		if opaque >= 100:
			return [total / float(opaque), float(opaque) / 288.0]
	return [Color(0, 0, 0, 0), 0.0]