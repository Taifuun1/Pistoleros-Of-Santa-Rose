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

	print("\n--- World agreement and fractional round-trips ---")
	for anchor in [[Vector2i(8, 17), Vector2i(20, 36)], [Vector2i(8, 12), Vector2i(40, 38)]]:
		var chunk: Vector2i = anchor[0]
		var tile: Vector2i = anchor[1]
		var cell := coordinates.chunkTileToCell(chunk, tile)
		var world := coordinates.chunkTileToWorld(chunk, tile)
		_check(world.distance_to(coordinates.cellToWorld(cell)) < 0.001, "chunkTileToWorld agrees with cellToWorld for {chunk}/{tile}".format({ "chunk": chunk, "tile": tile }))
		var fraction := coordinates.worldToCellFraction(world)
		_check(fraction.distance_to(Vector2(cell)) < 0.001, "worldToCellFraction round-trips the {chunk}/{tile} center".format({ "chunk": chunk, "tile": tile }))
		_check(coordinates.cellFractionToWorld(fraction).distance_to(world) < 0.001, "cellFractionToWorld round-trips the {chunk}/{tile} center".format({ "chunk": chunk, "tile": tile }))
	var motionCell := Vector2i(530, 1122)
	var motionCenter := coordinates.cellToWorld(motionCell)
	var quarterStep := motionCenter + (coordinates.cellToWorld(motionCell + Vector2i(1, 0)) - motionCenter) * 0.25
	var motionFraction := coordinates.worldToCellFraction(quarterStep)
	_check(absf(motionFraction.x - (motionCell.x + 0.25)) < 0.01 and absf(motionFraction.y - motionCell.y) < 0.01, "sub-cell motion along the u axis keeps a smooth fraction")
	for negativeCell in [Vector2i(-1, -1), Vector2i(-2, 0), Vector2i(0, -2), Vector2i(-70, 900)]:
		var negativeWorld := coordinates.cellToWorld(negativeCell)
		_check(coordinates.worldToCellFraction(negativeWorld).distance_to(Vector2(negativeCell)) < 0.001, "negative cell {cell} round-trips".format({ "cell": negativeCell }))

	print("\n--- Projection ---")
	_check(projection.imageSize == Vector2i(2304, 1152), "the full-grid image is 2304x1152 (cell footprints span one column wider than the lattice)")
	for cornerCell in [projection.cellMin, projection.cellMax, Vector2i(projection.cellMin.x, projection.cellMax.y), Vector2i(projection.cellMax.x, projection.cellMin.y)]:
		var cornerImage := projection.cellToImage(cornerCell)
		var cornerWorking := projection.cellToWorkingPixel(cornerCell)
		_check(cornerImage.x >= 0 and cornerImage.y >= 0 and cornerImage.x < projection.imageSize.x and cornerImage.y < projection.imageSize.y, "corner cell {cell} projects inside the final image".format({ "cell": cornerCell }))
		_check(cornerWorking.x >= 0 and cornerWorking.y >= 0 and cornerWorking.x < projection.workingSize.x and cornerWorking.y < projection.workingSize.y, "corner cell {cell} projects inside the working image".format({ "cell": cornerCell }))
	var neighborCell := Vector2i(100, 500)
	_check(projection.cellToWorkingPixel(neighborCell + Vector2i(1, 0)) - projection.cellToWorkingPixel(neighborCell) == Vector2i(1, 1), "+u neighbor projects (+1,+1) in working space")
	_check(projection.cellToWorkingPixel(neighborCell + Vector2i(0, 1)) - projection.cellToWorkingPixel(neighborCell) == Vector2i(-1, 1), "+v neighbor projects (-1,+1) in working space")
	_check(projection.cellToWorkingPixel(neighborCell + Vector2i(-1, 0)) - projection.cellToWorkingPixel(neighborCell) == Vector2i(-1, -1), "-u neighbor projects (-1,-1) in working space")
	_check(projection.cellToWorkingPixel(neighborCell + Vector2i(0, -1)) - projection.cellToWorkingPixel(neighborCell) == Vector2i(1, -1), "-v neighbor projects (+1,-1) in working space")
	var workingPixels := {}
	for localX in chunkTiles.x:
		for localY in chunkTiles.y:
			workingPixels[projection.cellToWorkingPixel(coordinates.chunkTileToCell(Vector2i(8, 12), Vector2i(localX, localY)))] = true
	_check(workingPixels.size() == chunkTiles.x * chunkTiles.y, "every fixture cell writes a unique working pixel")
	for sampleCell in [Vector2i(-2, -2), Vector2i(550, 804), Vector2i(530, 1122), Vector2i(765, 1533)]:
		_check(projection.imageToCellFraction(projection.cellToImage(sampleCell)).distance_to(Vector2(sampleCell)) < 0.001, "imageToCellFraction inverts cellToImage for {cell}".format({ "cell": sampleCell }))
	var halfCell := Vector2(neighborCell) + Vector2(0.5, 0)
	var halfExpected := (projection.cellToImage(neighborCell) + projection.cellToImage(neighborCell + Vector2i(1, 0))) * 0.5
	_check(projection.cellFractionToImage(halfCell).distance_to(halfExpected) < 0.001, "fractional cells project linearly between their integer neighbours")

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)