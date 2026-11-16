extends Node

const DEFAULT_CUTSCENE_ARC := "Pistoleros Regroup"
const DEFAULT_CUTSCENE_NAME := "Finch Pond"

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


## New Game: forget played cutscenes and restore the default arc/name.
func resetForNewGame() -> void:
	cutsceneArc = DEFAULT_CUTSCENE_ARC
	cutsceneName = DEFAULT_CUTSCENE_NAME
	playedCutscenes = PLAYED_CUTSCENES_DEFAULT.duplicate(true)
