extends RefCounted
class_name OverworldMapProjection

## Pure shared-cell / generated-image transforms (Docs/System Design/Journal/
## Overworld Map.md). Every orientation maps a shared cell (u, v) to a working
## pixel through an integer basis and then to the final image through an
## integer downsample, so the bake can rasterize losslessly before any
## filtering. Two orientations exist:
##
## - ORIENTATION_ISOMETRIC: the classic diamond, working (u - v, u + v),
##   halved vertically afterwards (image x = u - v, y = (u + v) / 2).
## - ORIENTATION_ALIGNED: the gameplay axes, working (4u, v) (image x = u,
##   y = v / 4). +u is screen right and +v is screen down in the Overworld,
##   and 4:1 is the Overworld's own chunk spacing (1536x384), so the map keeps
##   the world's on-screen silhouette instead of rotating it 45 degrees.
##
## The generated manifest records the orientation, so the runtime follows the
## data instead of guessing. All values are continuous in image space; markers
## never use rounded pixels.

const ORIENTATION_ISOMETRIC := 0
const ORIENTATION_ALIGNED := 1
## Orientation the checked-in map is generated with.
const SHIPPED_ORIENTATION := ORIENTATION_ALIGNED

var orientation: int
var cellMin: Vector2i
var cellMax: Vector2i
var workingOrigin: Vector2i
## Final-image origin; (workingOrigin - footprint origin) / downsample.
var mapOrigin: Vector2
var workingSize: Vector2i
var imageSize: Vector2i
## Working pixels one cell writes: the iso lattice pixel plus its x + 1 parity
## hole, or the aligned cell block. Footprints of different cells never overlap.
var workingCellFootprint: Vector2i
## Working-to-image divisor (the isometric vertical 1/2, none when aligned).
var downsample: Vector2i
## Final-image pixels per shared cell along +u and along +v.
var pixelsPerCell: Vector2

# Shared cell -> working pixel basis for the selected orientation.
var _workingBasisX: Vector2i
var _workingBasisY: Vector2i


func _init(minCell: Vector2i, maxCell: Vector2i, mapOrientation: int = SHIPPED_ORIENTATION) -> void:
	orientation = mapOrientation
	if !isKnownOrientation(orientation):
		push_error("OverworldMapProjection: unknown orientation {value}; using {fallback}".format({
			"value": mapOrientation, "fallback": orientationName(SHIPPED_ORIENTATION),
		}))
		orientation = SHIPPED_ORIENTATION
	if orientation == ORIENTATION_ALIGNED:
		_workingBasisX = Vector2i(4, 0)
		_workingBasisY = Vector2i(0, 1)
		workingCellFootprint = Vector2i(4, 1)
		downsample = Vector2i(1, 1)
		pixelsPerCell = Vector2(4.0, 1.0)
	else:
		_workingBasisX = Vector2i(1, 1)
		_workingBasisY = Vector2i(-1, 1)
		workingCellFootprint = Vector2i(2, 1)
		downsample = Vector2i(1, 2)
		pixelsPerCell = Vector2(1.0, 0.5)

	cellMin = minCell
	cellMax = maxCell
	# Extremes sit on cell-bounds corners for both bases; every cell then owns
	# the footprint starting at its working pixel.
	var minWorking := _workingBasisX * minCell.x + _workingBasisY * minCell.y
	var maxWorking := minWorking
	for cornerX in [minCell.x, maxCell.x]:
		for cornerY in [minCell.y, maxCell.y]:
			var cornerWorking: Vector2i = _workingBasisX * cornerX + _workingBasisY * cornerY
			minWorking = Vector2i(mini(minWorking.x, cornerWorking.x), mini(minWorking.y, cornerWorking.y))
			maxWorking = Vector2i(maxi(maxWorking.x, cornerWorking.x), maxi(maxWorking.y, cornerWorking.y))
	workingOrigin = minWorking
	workingSize = maxWorking + workingCellFootprint - minWorking
	imageSize = Vector2i(
		ceili(float(workingSize.x) / float(downsample.x)),
		ceili(float(workingSize.y) / float(downsample.y))
	)
	mapOrigin = Vector2(
		float(workingOrigin.x) / float(downsample.x),
		float(workingOrigin.y) / float(downsample.y)
	)


static func isKnownOrientation(value: int) -> bool:
	return value == ORIENTATION_ISOMETRIC or value == ORIENTATION_ALIGNED


static func orientationName(value: int) -> String:
	return "aligned" if value == ORIENTATION_ALIGNED else "isometric"


## Orientation id for a command-line/report name; -1 when unknown.
static func orientationFromName(name: String) -> int:
	match name.to_lower():
		"isometric":
			return ORIENTATION_ISOMETRIC
		"aligned":
			return ORIENTATION_ALIGNED
	return -1


## Projection over the full declared cell bounds of a chunk grid, including
## missing chunks, so a missing edge chunk appearing never shifts the image.
## Base cells are affine in the chunk coordinates, so per-axis extremes sit
## on grid corners; local tile keys run 0..chunkTiles-1 and the decode's
## -Vector2i.ONE makes each chunk cover base + [-1 .. chunkTiles-2].
static func cellForGrid(coordinates: OverworldCoordinates, chunkGrid: Rect2i, chunkTiles: Vector2i, mapOrientation: int = SHIPPED_ORIENTATION) -> OverworldMapProjection:
	var minBase := Vector2i()
	var maxBase := Vector2i()
	for cornerIndex in 4:
		var corner := Vector2i(
			chunkGrid.position.x + (cornerIndex % 2) * (chunkGrid.size.x - 1),
			chunkGrid.position.y + (cornerIndex / 2) * (chunkGrid.size.y - 1)
		)
		var base := coordinates.chunkToBaseCell(corner)
		if cornerIndex == 0:
			minBase = base
			maxBase = base
		else:
			minBase = Vector2i(mini(minBase.x, base.x), mini(minBase.y, base.y))
			maxBase = Vector2i(maxi(maxBase.x, base.x), maxi(maxBase.y, base.y))
	return OverworldMapProjection.new(
		minBase - Vector2i.ONE,
		maxBase + chunkTiles - Vector2i(2, 2),
		mapOrientation
	)


func hasCell(cell: Vector2i) -> bool:
	return cell.x >= cellMin.x and cell.x <= cellMax.x \
		and cell.y >= cellMin.y and cell.y <= cellMax.y


## Top-left working pixel of the cell's footprint; injective for every cell.
func cellToWorkingPixel(cell: Vector2i) -> Vector2i:
	return _workingBasisX * cell.x + _workingBasisY * cell.y - workingOrigin


## The cell's projected position in final-image pixels (its footprint origin,
## which is also the anchor markers use).
func cellToImage(cell: Vector2i) -> Vector2:
	return cellFractionToImage(Vector2(cell))


## Continuous image coordinate of a (possibly fractional) shared cell.
func cellFractionToImage(cellFraction: Vector2) -> Vector2:
	var working: Vector2 = Vector2(_workingBasisX) * cellFraction.x \
		+ Vector2(_workingBasisY) * cellFraction.y - Vector2(workingOrigin)
	return Vector2(
		working.x / float(downsample.x),
		working.y / float(downsample.y)
	)


## Inverse of cellFractionToImage, for mouse picking and centering (solves the
## 2x2 working basis, so it holds for both orientations).
func imageToCellFraction(imagePosition: Vector2) -> Vector2:
	var working := Vector2(imagePosition.x * downsample.x, imagePosition.y * downsample.y) \
		+ Vector2(workingOrigin)
	var xAxis := Vector2(_workingBasisX)
	var yAxis := Vector2(_workingBasisY)
	var determinant := xAxis.x * yAxis.y - xAxis.y * yAxis.x
	return Vector2(
		(working.x * yAxis.y - working.y * yAxis.x) / determinant,
		(xAxis.x * working.y - xAxis.y * working.x) / determinant
	)