extends Node

const DEFAULT_CUTSCENE_ARC := "Pistoleros Regroup"
const DEFAULT_CUTSCENE_NAME := "Finch Pond"
## Save snapshot format for exportState()/importState().
const STATE_FORMAT_VERSION := 1

var cutsceneArc = DEFAULT_CUTSCENE_ARC
var cutsceneName = DEFAULT_CUTSCENE_NAME

const PLAYED_CUTSCENES_DEFAULT = {
	"Finch Pond": false,
	"Pine Meadows": false,
	"Great Fall Ridge": false,
	"Blackberry Retreat": false,
	"Littlehill Grove": false
}

var playedCutscenes = PLAYED_CUTSCENES_DEFAULT.duplicate(true)


## Versioned save snapshot: the selected cutscene and the played flags.
func exportState() -> Dictionary:
	return {
		"formatVersion": STATE_FORMAT_VERSION,
		"cutsceneArc": cutsceneArc,
		"cutsceneName": cutsceneName,
		"playedCutscenes": playedCutscenes.duplicate(true),
	}


## Validates the whole payload before committing; malformed imports leave the
## current selection and flags untouched. Authored cutscenes are always present
## in the restored projection; a payload may add further known names.
func importState(state) -> Dictionary:
	if !(state is Dictionary) or int(state.get("formatVersion", -1)) != STATE_FORMAT_VERSION:
		return _failure("invalid_state")
	var arc = state.get("cutsceneArc", null)
	var name = state.get("cutsceneName", null)
	if typeof(arc) != TYPE_STRING or typeof(name) != TYPE_STRING:
		return _failure("invalid_state")
	if str(arc).is_empty() or str(name).is_empty():
		return _failure("invalid_state")
	var playedValue = state.get("playedCutscenes", null)
	if !(playedValue is Dictionary):
		return _failure("invalid_state")
	var played := PLAYED_CUTSCENES_DEFAULT.duplicate(true)
	for keyValue in playedValue:
		var key := str(keyValue)
		if key.is_empty() or typeof(playedValue[keyValue]) != TYPE_BOOL:
			return _failure("invalid_state")
		played[key] = bool(playedValue[keyValue])
	cutsceneArc = str(arc)
	cutsceneName = str(name)
	playedCutscenes = played
	return { "success": true, "reason": "" }


## New Game: forget played cutscenes and restore the default arc/name.
func resetForNewGame() -> void:
	cutsceneArc = DEFAULT_CUTSCENE_ARC
	cutsceneName = DEFAULT_CUTSCENE_NAME
	playedCutscenes = PLAYED_CUTSCENES_DEFAULT.duplicate(true)


func _failure(reason: String) -> Dictionary:
	return { "success": false, "reason": reason }
