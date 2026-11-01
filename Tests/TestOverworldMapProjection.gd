extends SceneTree

## Headless validation for OverworldCoordinates and OverworldMapProjection
## (Docs/System Design/Journal/Overworld Map.md): shared chunk/cell/world
## transforms, full-grid bounds, chunk seams, fractional round-trips and
## image-space corners. The staggered template transform (map basis
## u = (24, 0), v = (+/-12, 6) by row parity) is asserted through the real
## tileset via the shared helpers, never re-derived by hand.
## Run with: godot --headless --script res://Tests/TestOverworldMapProjection.gd

const HelperVariablesScript := preload("res://Globals/HelperVariables.gd")

var failures = 0
var coordinates: OverworldCoordinates
var projection: OverworldMapProjection
var chunkTiles: Vector2i


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var helperVars = HelperVariablesScript.new()
	chunkTiles = helperVars.overworldChunkSize
	helperVars.free()
	coordinates = OverworldCoordinates.makeHeadless()
	projection = OverworldMapProjection.cellForGrid(coordinates, WorldData.CHUNK_GRID, chunkTiles)

	print("--- Shared cell lattice ---")
	_check(coordinates.chunkToBaseCell(Vector2i(0, 0)) == Vector2i(-1, -1), "chunk (0,0) base cell is (-1,-1)")
	_check(coordinates.chunkToBaseCell(Vector2i(8, 12)) == Vector2i(511, 767), "chunk (8,12) base cell is (511,767)")
	_check(coordinates.chunkToBaseCell(Vector2i(9, 12)) - coordinates.chunkToBaseCell(Vector2i(8, 12)) == Vector2i(64, 0), "chunk +x steps 64 cells in u")
	_check(coordinates.chunkToBaseCell(Vector2i(8, 13)) - coordinates.chunkToBaseCell(Vector2i(8, 12)) == Vector2i(0, 64), "chunk +y steps 64 cells in v")
	_check(projection.cellMax - projection.cellMin == Vector2i(767, 1535), "the declared grid spans 768x1536 cells")
	_check(coordinates.chunkTileToCell(Vector2i(8, 17), Vector2i(20, 36)) == Vector2i(530, 1122), "Lazysprings anchor cell is (530,1122)")
	_check(coordinates.chunkTileToCell(Vector2i(8, 12), Vector2i(40, 38)) == Vector2i(550, 804), "initial player spawn cell is (550,804)")

	print("\n--- Chunk seams tile without gaps or overlaps ---")
	for chunk in [Vector2i(0, 0), Vector2i(5, 9), Vector2i(10, 23)]:
		var seamXLeft := coordinates.chunkTileToCell(chunk, Vector2i(chunkTiles.x - 1, 17))
		var seamXRight := coordinates.chunkTileToCell(chunk + Vector2i(1, 0), Vector2i(0, 17))
		_check(seamXRight - seamXLeft == Vector2i(1, 0), "x seam at chunk {chunk} is adjacent with no gap or overlap".format({ "chunk": chunk }))
		var seamYUp := coordinates.chunkTileToCell(chunk, Vector2i(17, chunkTiles.y - 1))
		var seamYDown := coordinates.chunkTileToCell(chunk + Vector2i(0, 1), Vector2i(17, 0))
		_check(seamYDown - seamYUp == Vector2i(0, 1), "y seam at chunk {chunk} is adjacent with no gap or overlap".format({ "chunk": chunk }))

	print("\n--- Cell to chunk/tile inverses ---")
	for anchor in [[Vector2i(8, 17), Vector2i(20, 36)], [Vector2i(8, 12), Vector2i(40, 38)], [Vector2i(0, 0), Vector2i(0, 0)], [Vector2i(11, 23), Vector2i(63, 63)]]:
		var anchorChunk: Vector2i = anchor[0]
		var anchorTile: Vector2i = anchor[1]
		var inverted: Dictionary = coordinates.cellToChunkTile(coordinates.chunkTileToCell(anchorChunk, anchorTile))
		_check(inverted["chunk"] == anchorChunk and inverted["tile"] == anchorTile, "cellToChunkTile inverts chunkTileToCell for {chunk}/{tile}".format({ "chunk": anchorChunk, "tile": anchorTile }))
	var firstInverted: Dictionary = coordinates.cellToChunkTile(coordinates.chunkTileToCell(Vector2i(1, 1), Vector2i(0, 0)))
	_check(firstInverted["chunk"] == Vector2i(1, 1) and firstInverted["tile"] == Vector2i(0, 0), "the first cell of a chunk inverts to tile (0,0)")
	var lastInverted: Dictionary = coordinates.cellToChunkTile(coordinates.chunkTileToCell(Vector2i(0, 0), Vector2i(63, 63)))
	_check(lastInverted["chunk"] == Vector2i(0, 0) and lastInverted["tile"] == Vector2i(63, 63), "the last cell of a chunk stays in the same chunk")
	var sweepOk := true
	for localX in [0, 1, 31, 32, 62, 63]:
		for localY in [0, 1, 31, 32, 62, 63]:
			var sweepInverted: Dictionary = coordinates.cellToChunkTile(coordinates.chunkTileToCell(Vector2i(8, 12), Vector2i(localX, localY)))
			if sweepInverted["chunk"] != Vector2i(8, 12) or sweepInverted["tile"] != Vector2i(localX, localY):
				sweepOk = false
	_check(sweepOk, "cellToChunkTile round-trips every sampled cell of the spawn chunk")

	print("\n--- World agreement and fractional round-trips ---")
	for anchor in [[Vector2i(8, 17), Vector2i(20, 36)], [Vector2i(8, 12), Vector2i(40, 38)]]:
		var chunk: Vector2i = anchor[0]
		var tile: Vector2i = anchor[1]
		var cell := coordinates.chunkTileToCell(chunk, tile)
		var world := coordinates.chunkTileToWorld(chunk, tile)
		_check(world.distance_to(coordinates.cellToWorld(cell)) < 0.001, "chunkTileToWorld agrees with cellToWorld for {chunk}/{tile}".format({ "chunk": chunk, "tile": tile }))
		var fraction := coordinates.worldToCellFraction(world)
		_check(fraction.distance_to(Vector2(cell)) < 0.001, "worldToCellFraction round-trips the {chunk}/{tile} center".format({ "chunk": chunk, "tile": tile }))
		var pair: Dictionary = coordinates.worldToCellAndFraction(world)
		_check(pair["cell"] == cell and (pair["fraction"] as Vector2).length() < 0.001, "worldToCellAndFraction round-trips the {chunk}/{tile} center".format({ "chunk": chunk, "tile": tile }))
		_check(coordinates.cellAndFractionToWorld(pair["cell"], pair["fraction"]).distance_to(world) < 0.001, "cellAndFractionToWorld round-trips the {chunk}/{tile} center".format({ "chunk": chunk, "tile": tile }))
	var motionCell := Vector2i(530, 1122)
	var motionCenter := coordinates.cellToWorld(motionCell)
	var quarterStep := motionCenter + (coordinates.cellToWorld(motionCell + Vector2i(1, 0)) - motionCenter) * 0.25
	var motionFraction := coordinates.worldToCellFraction(quarterStep)
	_check(absf(motionFraction.x - (motionCell.x + 0.25)) < 0.01 and absf(motionFraction.y - motionCell.y) < 0.01, "sub-cell motion along the u axis keeps a smooth fraction")
	for negativeCell in [Vector2i(-1, -1), Vector2i(-2, 0), Vector2i(0, -2), Vector2i(-70, 900)]:
		var negativeWorld := coordinates.cellToWorld(negativeCell)
		_check(coordinates.worldToCellFraction(negativeWorld).distance_to(Vector2(negativeCell)) < 0.001, "negative cell {cell} round-trips".format({ "cell": negativeCell }))

	print("\n--- Signed fractional round-trips and containing cells ---")
	# Signed offsets in every direction, exact axis-half boundaries and offsets
	# that cross into the next row/column, on both staggered row parities.
	var signedOffsets := [
		Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0),
		Vector2(-3.2, 0), Vector2(3.2, 0), Vector2(0, -3.2), Vector2(0, 3.2),
		Vector2(-5, 1), Vector2(5, -1), Vector2(-6, -3), Vector2(6, 3),
		Vector2(-12, 0), Vector2(12, 0), Vector2(0, -7), Vector2(0, 7),
	]
	var parityCells := [Vector2i(550, 804), Vector2i(551, 805), Vector2i(530, 1122), Vector2i(-2, -2), Vector2i(765, 1533)]
	var containingCellsOk := true
	var signedRoundTripsOk := true
	var numericFractionsOk := true
	for cell in parityCells:
		var center := coordinates.cellToWorld(cell)
		for offset in signedOffsets:
			var world: Vector2 = center + offset
			var expectedCell: Vector2i = coordinates._templateMap.local_to_map(coordinates._templateMap.to_local(world))
			if coordinates.worldToCell(world) != expectedCell:
				containingCellsOk = false
			var pair: Dictionary = coordinates.worldToCellAndFraction(world)
			if pair["cell"] != expectedCell:
				containingCellsOk = false
			if coordinates.cellAndFractionToWorld(pair["cell"], pair["fraction"]).distance_to(world) > 0.001:
				signedRoundTripsOk = false
			if coordinates.worldToCellFraction(world).distance_to(Vector2(pair["cell"]) + (pair["fraction"] as Vector2)) > 0.001:
				numericFractionsOk = false
	_check(containingCellsOk, "worldToCell and worldToCellAndFraction return the tile map's containing cell for signed offsets on both row parities")
	_check(signedRoundTripsOk, "signed ±u/±v world positions round-trip exactly through the cell+fraction contract")
	_check(numericFractionsOk, "worldToCellFraction stays consistent with the exact cell+fraction pair")

	print("\n--- Projection: both orientations ---")
	_check(projection.orientation == OverworldMapProjection.SHIPPED_ORIENTATION, "cellForGrid defaults to the shipped orientation")
	_check(projection.imageSize == Vector2i(3072, 1536), "the shipped aligned full-grid image is 3072x1536")
	_check(projection.pixelsPerCell == Vector2(4.0, 1.0), "the aligned map uses the Overworld's 4:1 chunk spacing")
	var isoProjection := OverworldMapProjection.cellForGrid(coordinates, WorldData.CHUNK_GRID, chunkTiles, OverworldMapProjection.ORIENTATION_ISOMETRIC)
	var neighborCell := Vector2i(100, 500)
	_check(isoProjection.imageSize == Vector2i(2304, 1152), "the isometric full-grid image stays 2304x1152")
	_check(isoProjection.mapOrigin == Vector2(-1535, -2), "the isometric origin is unchanged by the shared basis")
	_check(isoProjection.pixelsPerCell == Vector2(1.0, 0.5), "the isometric map keeps 1x0.5 pixels per cell")

	for subjectVariant in [projection, isoProjection]:
		var subject: OverworldMapProjection = subjectVariant
		var label := OverworldMapProjection.orientationName(subject.orientation)
		for cornerCell in [subject.cellMin, subject.cellMax, Vector2i(subject.cellMin.x, subject.cellMax.y), Vector2i(subject.cellMax.x, subject.cellMin.y)]:
			var cornerImage := subject.cellToImage(cornerCell)
			var cornerWorking := subject.cellToWorkingPixel(cornerCell)
			_check(cornerImage.x >= 0 and cornerImage.y >= 0 and cornerImage.x < subject.imageSize.x and cornerImage.y < subject.imageSize.y, "{orientation} corner cell {cell} projects inside the final image".format({ "orientation": label, "cell": cornerCell }))
			_check(cornerWorking.x >= 0 and cornerWorking.y >= 0 and cornerWorking.x < subject.workingSize.x and cornerWorking.y < subject.workingSize.y, "{orientation} corner cell {cell} fits the working image with its footprint".format({ "orientation": label, "cell": cornerCell }))
			_check(cornerWorking.x + subject.workingCellFootprint.x <= subject.workingSize.x and cornerWorking.y + subject.workingCellFootprint.y <= subject.workingSize.y, "{orientation} corner cell {cell} footprint is not clipped".format({ "orientation": label, "cell": cornerCell }))

		# Footprints must tile densely: every working pixel maps to exactly one cell.
		var covered := {}
		var overlap := false
		for localX in chunkTiles.x:
			for localY in chunkTiles.y:
				var cellPixel := subject.cellToWorkingPixel(coordinates.chunkTileToCell(Vector2i(8, 12), Vector2i(localX, localY)))
				for footprintY in subject.workingCellFootprint.y:
					for footprintX in subject.workingCellFootprint.x:
						var pixel := cellPixel + Vector2i(footprintX, footprintY)
						if covered.has(pixel):
							overlap = true
						covered[pixel] = true
		_check(!overlap, "{orientation} cell footprints never overlap".format({ "orientation": label }))
		_check(covered.size() == chunkTiles.x * chunkTiles.y * subject.workingCellFootprint.x * subject.workingCellFootprint.y, "{orientation} a full chunk tiles its working area densely".format({ "orientation": label }))

		for sampleCell in [Vector2i(-2, -2), Vector2i(550, 804), Vector2i(530, 1122), Vector2i(765, 1533)]:
			_check(subject.imageToCellFraction(subject.cellToImage(sampleCell)).distance_to(Vector2(sampleCell)) < 0.001, "{orientation} imageToCellFraction inverts cellToImage for {cell}".format({ "orientation": label, "cell": sampleCell }))
		var halfCell := Vector2(neighborCell) + Vector2(0.5, 0)
		var halfExpected := (subject.cellToImage(neighborCell) + subject.cellToImage(neighborCell + Vector2i(1, 0))) * 0.5
		_check(subject.cellFractionToImage(halfCell).distance_to(halfExpected) < 0.001, "{orientation} fractional cells project linearly between their integer neighbours".format({ "orientation": label }))
		var quarterCell := Vector2(neighborCell) + Vector2(0.0, 0.25)
		var quarterExpected := subject.cellToImage(neighborCell) + (subject.cellToImage(neighborCell + Vector2i(0, 1)) - subject.cellToImage(neighborCell)) * 0.25
		_check(subject.cellFractionToImage(quarterCell).distance_to(quarterExpected) < 0.001, "{orientation} fractional v motion projects linearly".format({ "orientation": label }))
		_check(subject.cellToImage(neighborCell + Vector2i(1, 0)).x > subject.cellToImage(neighborCell).x, "{orientation} +u always moves right in the image".format({ "orientation": label }))
		_check(subject.cellToImage(neighborCell + Vector2i(0, 1)).y > subject.cellToImage(neighborCell).y, "{orientation} +v always moves down in the image".format({ "orientation": label }))

	# Unknown values fail closed to the shipped orientation instead of
	# producing a transform the manifest never recorded.
	_check(!OverworldMapProjection.isKnownOrientation(7), "unknown orientation ids are rejected")
	_check(OverworldMapProjection.orientationFromName("aligned") == OverworldMapProjection.ORIENTATION_ALIGNED, "the aligned orientation parses from its command-line name")
	_check(OverworldMapProjection.orientationFromName("isometric") == OverworldMapProjection.ORIENTATION_ISOMETRIC, "the isometric orientation parses from its command-line name")
	_check(OverworldMapProjection.orientationFromName("diagonal") == -1, "unknown orientation names are rejected")

	print("\n--- Headless map ownership ---")
	var ownedCoordinates := OverworldCoordinates.makeHeadless()
	var ownedChunkMap := ownedCoordinates._chunkMap
	var ownedTemplateMap := ownedCoordinates._templateMap
	ownedCoordinates.dispose()
	_check(!is_instance_valid(ownedChunkMap) and !is_instance_valid(ownedTemplateMap), "disposing headless coordinates frees both owned maps")
	ownedCoordinates.dispose()
	_check(true, "disposing headless coordinates twice is safe")
	var borrowedChunkMap := TileMap.new()
	var borrowedTemplateMap := TileMap.new()
	var borrowedCoordinates := OverworldCoordinates.new(borrowedChunkMap, borrowedTemplateMap)
	borrowedCoordinates.dispose()
	_check(is_instance_valid(borrowedChunkMap) and is_instance_valid(borrowedTemplateMap), "disposing live coordinates does not free borrowed scene maps")
	borrowedChunkMap.free()
	borrowedTemplateMap.free()

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	coordinates.dispose()
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)