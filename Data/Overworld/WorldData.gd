extends RefCounted
class_name WorldData

## Authoritative Overworld world topology (Docs/System Design/Journal/
## Overworld Map.md): the declared chunk grid and the chunk scene directory.
## Not Zone geometry (see Data/Music/MusicData.gd) and not the per-chunk tile
## count (HelperVariables.overworldChunkSize stays the owner of that).

## Declared chunk grid. Missing chunks are coverage holes, not grid changes;
## bounds and the map derive from this rectangle, not from present files.
const CHUNK_GRID := Rect2i(0, 0, 12, 24)

## Tile size of the square chunk-frame map in Overworld.tscn (one chunk per
## cell). Declared here because it exists nowhere else but that sub-resource.
const CHUNK_MAP_TILE_SIZE := Vector2i(1536, 384)

## The isometric template-grid tileset shared by MergedTiles, the chunk
## template and the chunks.
const TEMPLATE_TILESET_PATH := "res://Tilesets/OverworldTileset.tres"

const CHUNK_PATH_FORMAT := "res://Overworld/Overworld Chunks/#{x}#{y}.tscn"


static func getChunkPath(chunk: Vector2i) -> String:
	return CHUNK_PATH_FORMAT.format({ "x": chunk.x, "y": chunk.y })


static func hasChunkScene(chunk: Vector2i) -> bool:
	return ResourceLoader.exists(getChunkPath(chunk))