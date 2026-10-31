extends RefCounted
class_name OverworldMapProjection

## Pure shared-cell / generated-image transforms (Docs/System Design/Journal/
## Overworld Map.md): projected.x = u - v, projected.y = (u + v) * 0.5, image
## coordinate = projected - mapOrigin. The generator rasterizes through a
## lossless working surface (pixel = (u - v, u + v) - workingOrigin, halved
## vertically afterwards) so fractional final rows never collide cells; those
## working details live here so the bake and future runtime markers share one
## transform. All values are continuous; markers never use rounded pixels.

var cellMin: Vector2i
var cellMax: Vector2i
var workingOrigin: Vector2i
## Final-image origin: (workingOrigin.x, workingOrigin.y * 0.5).
var mapOrigin: Vector2
var workingSize: Vector2i
var imageSize: Vector2i


func _init(minCell: Vector2i, maxCell: Vector2i) -> void:
	cellMin = minCell
	cellMax = maxCell
	workingOrigin = Vector2i(minCell.x - maxCell.y, minCell.x + minCell.y)
	mapOrigin = Vector2(workingOrigin.x, workingOrigin.y * 0.5)
	# The cell lattice (u - v, u + v) only hits working pixels whose x and y
	# share parity, i.e. half the surface; each cell covers a 2x1 footprint
	# (its own pixel plus the x + 1 parity hole, which no other cell claims)
	# so the working image tiles densely. Width therefore spans the cell
	# footprints, one column wider than the distinct lattice columns.
	workingSize = Vector2i(
		(maxCell.x - minCell.y) - (minCell.x - maxCell.y) + 2,
		(maxCell.x + maxCell.y) - (minCell.x + minCell.y) + 1
	)
	imageSize = Vector2i(workingSize.x, ceili(float(workingSize.y) / 2.0))


## Projection over the full declared cell bounds of a chunk grid, including
## missing chunks, so a missing edge chunk appearing never shifts the image.
## Base cells are affine in the chunk coordinates, so per-axis extremes sit
## on grid corners; local tile keys run 0..chunkTiles-1 and the decode's
## -Vector2i.ONE makes each chunk cover base + [-1 .. chunkTiles-2].
static func cellForGrid(coordinates: OverworldCoordinates, chunkGrid: Rect2i, chunkTiles: Vector2i) -> OverworldMapProjection:
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
		maxBase + chunkTiles - Vector2i(2, 2)
	)


func hasCell(cell: Vector2i) -> bool:
	return cell.x >= cellMin.x and cell.x <= cellMax.x \
		and cell.y >= cellMin.y and cell.y <= cellMax.y


## Exactly one working pixel per source cell; injective by construction.
func cellToWorkingPixel(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x - cell.y, cell.x + cell.y) - workingOrigin


func cellToImage(cell: Vector2i) -> Vector2:
	return cellFractionToImage(Vector2(cell))


## Continuous image coordinate of a (possibly fractional) shared cell.
func cellFractionToImage(cellFraction: Vector2) -> Vector2:
	return Vector2(
		cellFraction.x - cellFraction.y,
		(cellFraction.x + cellFraction.y) * 0.5
	) - mapOrigin


## Inverse of cellFractionToImage, for mouse picking and centering.
func imageToCellFraction(imagePosition: Vector2) -> Vector2:
	var projected := imagePosition + mapOrigin
	var total := projected.y * 2.0
	var difference := projected.x
	return Vector2((difference + total) * 0.5, (total - difference) * 0.5)