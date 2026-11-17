extends Node

## Child-process half of the application-restart proof (Tests/TestSaveRestart.tscn):
## a second Godot process reads the save file the first process wrote and checks
## every restored domain against the expectations passed as user arguments, so the
## restore is proven against a genuinely fresh process rather than a reset in the
## same one. The name deliberately has no "Test" prefix: RunAll must not run it
## standalone (it has nothing to verify without a save file).
## Run as: godot --headless --path . res://Tests/SaveRestartVerify.tscn -- money=640 ...

const QUEST_ID := "pistoleros_regroup"

var failures := 0
var lines := []
var saveGame: Node


func _ready() -> void:
	saveGame = get_tree().root.get_node_or_null("SaveGame")
	_check(saveGame != null, "the save service autoload exists in the fresh process")
	if saveGame != null:
		_check(saveGame.hasValidSave(), "the file written by the previous process is valid")
		var restored: Dictionary = saveGame.loadSave()
		_check(bool(restored.get("success", false)), "the restore succeeds: %s" % str(restored))
		_check(int(restored.get("migratedFrom", -1)) == saveGame.SAVE_FORMAT_VERSION, "the file is the current format")

	_check(Party.money == _expectInt("money", -1), "money restores exactly (%d)" % Party.money)
	_check(Locations.isOnTrail(), "the active Trail is restored")
	_check(Locations.trailDepartureId == _expectInt("departure", -1), "the departure cycle is restored")
	_check(Locations.getLastTownId() == "Lazysprings", "the last resupply Town is restored")
	_check(Quests.getCurrentObjectiveId(QUEST_ID) == _expectString("objective", ""), "the current quest objective is restored")
	_check(Discovery.isRevealed(_expectString("reveal", "")), "the map reveal is restored")
	_check(bool(Cutscene.playedCutscenes.get("Finch Pond", false)), "the played cutscene flag is restored")
	_check(int(Vendors.exportState().baseSeed) == _expectInt("seed", -1), "the vendor run seed is restored")
	_check(int(Vendors.exportState().activeDepartureId) == Locations.trailDepartureId, "the vendor stock cycle stays synchronized with the Trail")

	var belt: Dictionary = Party.getBeltSnapshot("Walker Langley")
	_check(int(belt.get("used", -1)) == _expectInt("belt", -1), "the belt reservation count is restored")
	var expectedMoves: Array = _expectString("moves", "").split("|", false)
	_check(Party.party["Walker Langley"]["moves"] == expectedMoves, "the selected Move loadout is restored (%s)" % str(Party.party["Walker Langley"]["moves"]))
	_check(Party.getFightData("Walker Langley").moves == expectedMoves, "the restored loadout resolves against the real class grants")
	var weapon = Party.party["Walker Langley"]["equipment"].get("weapon", {})
	_check(str(weapon.get("definitionId", "")) == _expectString("weapon", ""), "the equipped granting weapon is restored")
	_check(weapon.get("grantedMoves", []) == ["Sharp Shot"], "the equipment grant data survives the restart")
	var ids := {}
	var duplicate := false
	for entryValue in Party.inventory:
		var instanceId := str((entryValue as Dictionary).get("instanceId", ""))
		if ids.has(instanceId):
			duplicate = true
		ids[instanceId] = true
	_check(!duplicate, "carried instance ids stay unique after the restart")
	for reservation in belt.get("entries", []):
		_check(ids.has(str(reservation.get("instanceId", ""))), "every restored reservation references a carried stack")

	var expectedPosition := Vector2(_expectFloat("pos_x", 0.0), _expectFloat("pos_y", 0.0))
	var positionInfo: Dictionary = Overworld.getOverworldMapPosition()
	_check(positionInfo.get("world_position", Vector2.ZERO) == expectedPosition, "the exact Overworld position is restored (%s)" % str(positionInfo.get("world_position")))
	var coordinates := OverworldCoordinates.makeHeadless()
	var expectedCell := coordinates.cellToChunkTile(coordinates.worldToCell(expectedPosition))
	coordinates.dispose()
	_check(Overworld.spawnChunk == expectedCell.chunk and Overworld.spawnTile == expectedCell.tile, "re-entry is anchored on the restored position's cell")

	_writeLog()
	if failures == 0:
		print("RESTART VERIFY: ALL CHECKS PASSED")
	else:
		print("RESTART VERIFY: %d CHECK(S) FAILED" % failures)
	get_tree().quit(failures)


func _writeLog() -> void:
	var file := FileAccess.open(OS.get_user_data_dir() + "/save_restart_verify_child.log", FileAccess.WRITE)
	if file == null:
		return
	for line in lines:
		file.store_line(line)
	file.close()


func _expectString(key: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with(key + "="):
			return text.substr(key.length() + 1)
	return fallback


func _expectInt(key: String, fallback: int) -> int:
	return int(_expectString(key, str(fallback)))


func _expectFloat(key: String, fallback: float) -> float:
	return float(_expectString(key, str(fallback)))


func _check(condition: bool, message: String) -> void:
	if condition:
		lines.append("PASS: " + message)
		print("PASS: ", message)
	else:
		failures += 1
		lines.append("FAIL: " + message)
		printerr("FAIL: ", message)
