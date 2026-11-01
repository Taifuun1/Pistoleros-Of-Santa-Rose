extends SceneTree

## Subprocess regression tests for the map generator's fail-closed CLI policy
## (Docs/System Design/Journal/Overworld Map.md, iteration step 3): every mode
## exits with a meaningful status, invalid input refuses to bake or write, and
## no mode mutates the committed generated outputs. Each case runs a real child
## Godot process so the tested behavior is exactly the command-line contract.
## Run with: godot --headless --script res://Tests/TestOverworldMapCli.gd

const GENERATOR_SCRIPT := "res://Tools/GenerateOverworldMap.gd"
const OUTPUT_PATHS := [
	"res://Assets/Journal/OverworldMap.png",
	"res://Assets/Journal/OverworldMapOverview.png",
	"res://Data/Overworld/OverworldMapData.tres",
]

var failures := 0
var checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("--- Generator CLI exit statuses ---")
	var outputsBefore := _outputHashes()

	var checkResult := _runGenerator(["--check"])
	_check(checkResult["exitCode"] == 0, "--check exits 0 on current outputs")
	_check(checkResult["output"].contains("committed outputs are current"), "--check reports that the committed outputs are current")

	var requireResult := _runGenerator(["--require-complete"])
	_check(requireResult["exitCode"] == 1, "--require-complete exits nonzero while chunks are missing")
	_check(requireResult["output"].contains("--require-complete"), "--require-complete explains the missing-chunk failure")

	var strictResult := _runGenerator(["--strict"])
	_check(strictResult["exitCode"] == 1, "--strict exits nonzero while seam overlaps exist")
	_check(strictResult["output"].contains("--strict"), "--strict names the failing policy")

	var surveyResult := _runGenerator(["--survey"])
	_check(surveyResult["exitCode"] == 0, "--survey exits 0 on clean chunk data")
	_check(surveyResult["output"].contains("distinct tile keys"), "--survey still prints its palette survey")

	var paletteResult := _runGenerator(["--palette-report"])
	_check(paletteResult["exitCode"] == 0, "--palette-report exits 0 when no source collapses and no key is unknown")
	_check(paletteResult["output"].contains("unknown keys: none"), "--palette-report reports complete key coverage")

	var previewResult := _runGenerator(["--preview", "--orientation=aligned"])
	_check(previewResult["exitCode"] == 0, "--preview exits 0 on a clean bake")
	_check(previewResult["output"].contains("preview:"), "--preview reports the written preview files")

	var previewStrictResult := _runGenerator(["--preview", "--strict"])
	_check(previewStrictResult["exitCode"] == 1, "--preview fails closed when --strict finds seam overlaps")

	print("\n--- Invalid CLI input fails closed ---")
	var unknownArgResult := _runGenerator(["--unknown-arg"])
	_check(unknownArgResult["exitCode"] == 1, "an unknown argument exits nonzero")
	_check(unknownArgResult["output"].contains("refusing to bake or write"), "an unknown argument refuses to bake or write")

	var badOrientationResult := _runGenerator(["--orientation=diagonal"])
	_check(badOrientationResult["exitCode"] == 1, "an unknown orientation exits nonzero")
	_check(badOrientationResult["output"].contains("refusing to bake or write"), "an unknown orientation refuses to bake or write")

	var outputsAfter := _outputHashes()
	_check(str(outputsBefore) == str(outputsAfter), "no CLI mode changed the committed generated outputs")

	if failures == 0:
		print("\nTestOverworldMapCli: %d checks passed" % checks)
		print("\nALL CHECKS PASSED")
	else:
		print("\nTestOverworldMapCli: %d passed, %d failed" % [checks - failures, failures])
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


## Runs the generator as a real child process and returns
## { "exitCode": int, "output": String }.
func _runGenerator(arguments: Array) -> Dictionary:
	var output: Array = []
	var command := PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", GENERATOR_SCRIPT,
		"--",
	])
	for argument in arguments:
		command.append(str(argument))
	var exitCode := OS.execute(OS.get_executable_path(), command, output, true)
	return { "exitCode": exitCode, "output": "\n".join(output) }


func _outputHashes() -> Dictionary:
	var hashes := {}
	for path in OUTPUT_PATHS:
		hashes[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	return hashes


func _check(condition: bool, message: String) -> void:
	checks += 1
	if !condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
