extends SceneTree

## Runs every automated test in one go, one isolated Godot process per test.
##
## Tests must stay isolated because each one wants to be the main loop (the
## SceneTree scripts) or own the tree (the scene-run ones), so the runner
## spawns a child Godot per test and gates the run on its exit code.
##
## Run with:
##   godot --headless --script res://Tests/RunAll.gd
## Narrow to matching tests (substring, case-insensitive) with user args:
##   godot --headless --script res://Tests/RunAll.gd -- Music Targeting
##
## Discovered automatically: Tests/Test*.gd (headless --script) and
## Tests/Test*.tscn (run as scenes). When a test has both forms, only the
## scene runs — the scene is the canonical invocation (TestShootoutTurnTiming
## needs the project autoloads, which --script mode does not load).
## EXTRA_SCENE_TESTS adds the automated in-tree scene tests that quit with a
## real exit code. Poker's and the Scene Manager's tests quit()
## unconditionally (always exit 0), so they cannot gate a pass/fail run and
## are left out of the automated set.
##
## Each test's output goes into its own log file under the project's user
## data dir (runall/<Test>.log) and is echoed when the test finishes: spawned
## children do not reliably inherit the runner's redirected output, and this
## keeps a failing test's checks readable.

const RUNNER_NAME = "RunAll.gd"
## Generous ceiling per test: these suites exist because of soft locks, so a
## hung test must fail the run instead of hanging it.
const SCRIPT_TIMEOUT_SECONDS = 120.0
const SCENE_TIMEOUT_SECONDS = 300.0

# In-tree scene tests with meaningful exit codes (see the header note).
const EXTRA_SCENE_TESTS = [
	"res://Location/Location Generation/Test/WFCSolverTest.tscn",
	"res://Location/Location Generation/Test/WFCIntegrationTest.tscn",
	"res://Location/Location Generation/Test/ClearwaterGroveSceneTest.tscn",
	"res://Minigames/Gold Rush/Test/RobbingTest.tscn",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var filters = []
	for arg in OS.get_cmdline_user_args():
		filters.append(str(arg).to_lower())

	var tests = _discoverTests()
	for filter in filters:
		tests = tests.filter(func(test): return test.name.to_lower().contains(filter))

	if tests.is_empty():
		printerr("RunAll: no tests match %s" % str(filters))
		quit(1)
		return
	_cleanLogDir()

	var results = []
	for test in tests:
		print("\n===== %s (%s) =====" % [test.name, test.kind])
		var seconds = Time.get_ticks_msec() / 1000.0
		var process = _spawnTest(test)
		if process.pid <= 0:
			results.append(_result(test, false, "spawn failed", 0.0))
			continue
		var outcome = await _waitUntilDone(process.pid, test.timeoutSeconds)
		seconds = Time.get_ticks_msec() / 1000.0 - seconds
		if outcome.timedOut:
			results.append(_result(test, false, "TIMED OUT after %ds (killed)" % int(test.timeoutSeconds), seconds))
		elif outcome.exitCode == 0:
			results.append(_result(test, true, "ok", seconds))
		else:
			results.append(_result(test, false, "exit code %d" % outcome.exitCode, seconds))
		_echoLog(process)

	_printSummary(results)
	quit(results.filter(func(result): return !result.passed).size())


func _discoverTests() -> Array:
	# A test with a sibling scene runs only as the scene: --script mode has no
	# autoloads, and TestShootoutTurnTiming.gd depends on them.
	var sceneBases = {}
	for fileName in DirAccess.get_files_at("res://Tests"):
		if fileName.begins_with("Test") and fileName.ends_with(".tscn"):
			sceneBases[fileName.get_basename()] = true
	var tests = []
	for fileName in DirAccess.get_files_at("res://Tests"):
		if !fileName.begins_with("Test") or fileName == RUNNER_NAME:
			continue
		if fileName.ends_with(".gd") and !sceneBases.has(fileName.get_basename()):
			tests.append({ "name": fileName.get_basename(), "args": ["--script", "res://Tests/" + fileName], "timeoutSeconds": SCRIPT_TIMEOUT_SECONDS, "kind": "script" })
		elif fileName.ends_with(".tscn"):
			tests.append({ "name": fileName.get_basename(), "args": ["res://Tests/" + fileName], "timeoutSeconds": SCENE_TIMEOUT_SECONDS, "kind": "scene" })
	for scenePath in EXTRA_SCENE_TESTS:
		if ResourceLoader.exists(scenePath):
			tests.append({ "name": scenePath.get_file().get_basename(), "args": [scenePath], "timeoutSeconds": SCENE_TIMEOUT_SECONDS, "kind": "scene" })
	tests.sort_custom(func(a, b): return a.name < b.name)
	return tests


func _spawnTest(test: Dictionary) -> Dictionary:
	var arguments = ["--headless", "--path", ProjectSettings.globalize_path("res://")]
	arguments.append_array(test.args)
	var logPath = _logDir() + "/" + test.name + ".log"
	# Child output does not follow the runner's own redirection, so route it
	# into a per-test log file. On Windows this goes through a tiny batch file:
	# a `cmd /C "..."` one-liner hits cmd's quote-stripping rules and breaks
	# quoting for the (spacey) Godot path.
	var quoted = ["\"%s\"" % OS.get_executable_path()]
	for argument in arguments:
		quoted.append("\"%s\"" % argument)
	var launcherPath = _logDir() + "/" + test.name + ".cmd"
	var pid = 0
	if OS.get_name() == "Windows":
		var batch = FileAccess.open(launcherPath, FileAccess.WRITE)
		batch.store_line("@echo off")
		batch.store_line(" ".join(quoted) + " > \"%s\" 2>&1" % logPath)
		batch.store_line("exit /B %ERRORLEVEL%")
		batch.close()
		pid = OS.create_process("cmd", ["/C", launcherPath])
	else:
		var command = " ".join(quoted) + " > \"%s\" 2>&1" % logPath
		pid = OS.create_process("sh", ["-c", command])
	return { "pid": pid, "logPath": logPath, "launcherPath": launcherPath }


func _logDir() -> String:
	var directory = OS.get_user_data_dir() + "/runall"
	DirAccess.make_dir_recursive_absolute(directory)
	return directory


## The end-of-test log removal is best-effort (Windows can still hold the just-
## closed redirect file briefly), so each run starts from a clean directory
## instead of letting logs accumulate.
func _cleanLogDir() -> void:
	var directory = DirAccess.open(_logDir())
	if directory == null:
		return
	for fileName in directory.get_files():
		directory.remove(fileName)


## Prints the test's captured output and cleans the log and launcher files up.
func _echoLog(process: Dictionary) -> void:
	var file = FileAccess.open(process.logPath, FileAccess.READ)
	if file != null:
		print(file.get_as_text())
		DirAccess.remove_absolute(process.logPath)
	DirAccess.remove_absolute(process.launcherPath)


## Polls the child process every tick so a hung test hits the timeout instead
## of freezing the whole run (OS.execute would block forever).
func _waitUntilDone(pid: int, timeoutSeconds: float) -> Dictionary:
	var deadline = Time.get_ticks_msec() + int(timeoutSeconds * 1000.0)
	while OS.is_process_running(pid):
		if Time.get_ticks_msec() >= deadline:
			OS.kill(pid)
			return { "timedOut": true, "exitCode": -1 }
		await create_timer(0.1).timeout
	return { "timedOut": false, "exitCode": OS.get_process_exit_code(pid) }


func _result(test: Dictionary, passed: bool, detail: String, seconds: float) -> Dictionary:
	return { "name": test.name, "passed": passed, "detail": detail, "seconds": seconds }


func _printSummary(results: Array) -> void:
	print("\n===== Summary =====")
	for result in results:
		print("%s  %s  (%.1fs%s)" % ["PASS" if result.passed else "FAIL", result.name, result.seconds, "" if result.detail == "ok" else ", " + result.detail])
	var failed = results.filter(func(result): return !result.passed)
	if failed.is_empty():
		print("\nALL %d TEST(S) PASSED" % results.size())
	else:
		printerr("\n%d/%d TEST(S) FAILED" % [failed.size(), results.size()])