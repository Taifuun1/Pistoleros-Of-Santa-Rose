extends RefCounted
class_name OverworldChunkReader

## Shared chunk scene/script decoding (Docs/System Design/Journal/Overworld
## Map.md), extracted from Overworld.gd so live streaming and the map
## generator read identical cells; no second decoder exists. Decodes a ready
## PackedScene — loading, caching and background parsing stay with callers.

var _coordinates: OverworldCoordinates


func _init(coordinates: OverworldCoordinates) -> void:
	_coordinates = coordinates


## Full chunk read: baked tile cells plus the per-chunk data script's
## locations/spawnPoints. "cells" holds the live six-int records
## [cellX, cellY, sourceId, atlasX, atlasY, alternative] in shared-cell
## coordinates; "locations"/"spawnPoints" pass the script dictionaries
## through unchanged (the manifest generator normalizes them).
## Errors are reported, never silently repaired.
func readChunk(chunk: Vector2i, packedScene: PackedScene) -> Dictionary:
	var result := { "cells": PackedInt32Array(), "locations": {}, "spawnPoints": {}, "errors": [] }
	if packedScene == null:
		result["errors"].append("chunk {chunk} has no scene".format({ "chunk": chunk }))
		return result
	result["cells"] = readCells(chunk, packedScene)
	var chunkScript := getChunkScript(packedScene)
	if chunkScript == null:
		return result
	var chunkData = chunkScript.new()
	if chunkData == null:
		result["errors"].append("chunk {chunk} script could not be instantiated".format({ "chunk": chunk }))
		return result
	if "locations" in chunkData:
		result["locations"] = chunkData.locations
	if "spawnPoints" in chunkData:
		result["spawnPoints"] = chunkData.spawnPoints
	chunkData.free()
	return result


## The chunk's baked tiles as shared-cell records, byte-for-byte the decode
## the live merged-layer cache uses (signed 16-bit components, the
## -Vector2i.ONE local correction, six ints per cell).
func readCells(chunk: Vector2i, packedScene: PackedScene) -> PackedInt32Array:
	var cellData := PackedInt32Array()
	if packedScene == null:
		return cellData
	var baseCell := _coordinates.chunkToBaseCell(chunk)
	var state := packedScene.get_state()
	for n in range(state.get_node_count()):
		for p in range(state.get_node_property_count(n)):
			if state.get_node_property_name(n, p) != "layer_0/tile_data":
				continue
			var data: PackedInt32Array = state.get_node_property_value(n, p)
			for i in range(0, data.size() - 2, 3):
				var packedCoords: int = data[i]
				var packedTile: int = data[i + 1]
				var packedAtlas: int = data[i + 2]
				var cell := baseCell + Vector2i(
					_s16(packedCoords & 0xFFFF),
					_s16((packedCoords >> 16) & 0xFFFF)
				) - Vector2i(1, 1)
				cellData.append(cell.x)
				cellData.append(cell.y)
				cellData.append(_s16(packedTile & 0xFFFF))
				cellData.append(_s16((packedTile >> 16) & 0xFFFF))
				cellData.append(_s16(packedAtlas & 0xFFFF))
				cellData.append(_s16((packedAtlas >> 16) & 0xFFFF))
	return cellData


## The per-chunk data script (locations/spawnPoints), if the scene's root
## node has one.
static func getChunkScript(packedScene: PackedScene) -> Script:
	var state := packedScene.get_state()
	for n in range(state.get_node_count()):
		for p in range(state.get_node_property_count(n)):
			if state.get_node_property_name(n, p) == "script":
				return state.get_node_property_value(n, p)
	return null


## Sign-extends a 16-bit packed component of the baked tile_data format.
static func _s16(value: int) -> int:
	if value >= 0x8000:
		return value - 0x10000
	return value