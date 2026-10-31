extends Resource
class_name OverworldMapData

## Generated Overworld map manifest (Docs/System Design/Journal/Overworld
## Map.md). Written only by Tools/GenerateOverworldMap.gd and checked in;
## the game only reads it. Player/quest state and the current Zone are
## deliberately absent — dynamic markers resolve through the projection and
## their own providers at runtime.

const FORMAT_VERSION := 1

@export var format_version: int = FORMAT_VERSION
@export var texture: Texture2D = null
@export var image_size: Vector2i = Vector2i.ZERO
@export var map_origin: Vector2 = Vector2.ZERO
@export var pixels_per_cell: Vector2 = Vector2(1.0, 0.5)
@export var chunk_grid: Rect2i = Rect2i()
## Shared-cell bounds of the generated projection; the runtime projection is
## rebuilt directly from these so markers and the bake can never disagree.
@export var cell_min: Vector2i = Vector2i.ZERO
@export var cell_max: Vector2i = Vector2i.ZERO
## Covers the sorted chunk scenes (including missing ones), their chunk
## scripts, the shared tileset, world/style data and the shared
## coordinate/reader/projection/baker code. Any of those changing makes a
## committed manifest stale (--check fails).
@export var source_fingerprint: String = ""
## Normalized Location manifest entries: { "id", "display_name", "chunk",
## "tile", "cell", "image_position", "icon" }.
@export var locations: Array[Dictionary] = []


## True when the committed data matches a freshly generated manifest.
func matches(other: OverworldMapData) -> bool:
	return format_version == other.format_version \
		and image_size == other.image_size \
		and map_origin == other.map_origin \
		and pixels_per_cell == other.pixels_per_cell \
		and chunk_grid == other.chunk_grid \
		and cell_min == other.cell_min \
		and cell_max == other.cell_max \
		and source_fingerprint == other.source_fingerprint \
		and locations == other.locations


func resolveLocation(targetId: String) -> Dictionary:
	for location in locations:
		if location["id"] == targetId:
			return location
	return {}