extends SceneTree

## Headless validation for the cutscene snapshot contract (Docs/System Design/
## First Steps Implementation Plan.md, save-service commit): versioned
## export/import/reset, the played-flag projection and malformed rollback.
## Run with: godot --headless --script res://Tests/TestCutsceneState.gd

const CutsceneScript = preload("res://Globals/Cutscene.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("--- Initial state and round trip ---")
	var source = CutsceneScript.new()
	source.cutsceneName = "Pine Meadows"
	source.playedCutscenes["Finch Pond"] = true
	var snapshot: Dictionary = source.exportState()
	_check(snapshot.formatVersion == 1, "the snapshot carries the state format version")
	_check(snapshot.cutsceneName == "Pine Meadows", "the snapshot records the selected cutscene")

	var target = CutsceneScript.new()
	_check(target.importState(snapshot).success, "the snapshot imports")
	_check(target.exportState() == snapshot, "export/import/export is stable")
	_check(target.playedCutscenes.size() == CutsceneScript.PLAYED_CUTSCENES_DEFAULT.size(), "every authored cutscene id stays present")

	print("\n--- Malformed payloads leave state untouched ---")
	var before: Dictionary = target.exportState()
	var cases := {
		"a future format version": { "formatVersion": 99, "cutsceneArc": "a", "cutsceneName": "b", "playedCutscenes": {} },
		"a missing name": { "formatVersion": 1, "cutsceneArc": "a", "cutsceneName": "", "playedCutscenes": {} },
		"a non-dictionary flag map": { "formatVersion": 1, "cutsceneArc": "a", "cutsceneName": "b", "playedCutscenes": [] },
		"a non-boolean flag": { "formatVersion": 1, "cutsceneArc": "a", "cutsceneName": "b", "playedCutscenes": { "Finch Pond": "yes" } },
		"an empty cutscene key": { "formatVersion": 1, "cutsceneArc": "a", "cutsceneName": "b", "playedCutscenes": { "": true } },
	}
	for label in cases:
		_check(target.importState(cases[label]).reason == "invalid_state", "%s is rejected" % label)
	_check(target.exportState() == before, "no rejected payload committed anything")

	print("\n--- New Game reset ---")
	target.resetForNewGame()
	var reset: Dictionary = target.exportState()
	_check(reset.cutsceneArc == CutsceneScript.DEFAULT_CUTSCENE_ARC and reset.cutsceneName == CutsceneScript.DEFAULT_CUTSCENE_NAME, "New Game restores the default selection")
	_check(reset.playedCutscenes.values().count(true) == 0, "New Game clears every played flag")

	source.free()
	target.free()
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)
