extends Node

const INITIAL_CHUNK_TIMEOUT_SECONDS := 5.0
const BACKGROUND_GENERATION_TIMEOUT_SECONDS := 30.0
const MAX_FRAME_GAP_SECONDS := 0.1

var _map: Node
var _startedAtUsec := 0
var _lastProcessAtUsec := 0
var _initialChunkAtUsec := 0
var _maxFrameGap := 0.0


func _ready() -> void:
	_startedAtUsec = Time.get_ticks_usec()
	_lastProcessAtUsec = _startedAtUsec
	Locations.currentLocation = "Clearwater Grove"
	_map = load("res://Location/Location Generation/Clearwater Grove/ClearwaterGrove.tscn").instantiate()
	add_child(_map)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	# Use monotonic wall time rather than accumulated frame deltas. Godot clamps
	# delta after a long blocked frame, which previously let the exact startup
	# freeze this test covers appear to complete in a fraction of a second.
	var elapsed := (now - _startedAtUsec) / 1_000_000.0
	if _initialChunkAtUsec == 0 and elapsed >= INITIAL_CHUNK_TIMEOUT_SECONDS:
		_fail("timed out; generated=%d, empty=%d, idle=%s, models=%s" % [
			_map.generatedChunks.size(),
			_map.emptyChunks.size(),
			str(_map.idleGenerators),
			str(WaveFunctionCollapse.models.keys())
		])
		return

	if _initialChunkAtUsec == 0 and _map.generatedChunks.has(Vector2i.ZERO):
		# Give LocationMapBase._process one more frame to display the initial chunk.
		set_process(false)
		await get_tree().process_frame
		var used_cells: int = _map.get_node("Map").get_used_cells(0).size()
		if used_cells <= 0:
			_fail("initial chunk generated but was not displayed")
			return
		_initialChunkAtUsec = Time.get_ticks_usec()
		_lastProcessAtUsec = _initialChunkAtUsec
		set_process(true)
		return

	if _initialChunkAtUsec == 0:
		_lastProcessAtUsec = now
		return

	var frameGap := (now - _lastProcessAtUsec) / 1_000_000.0
	_maxFrameGap = maxf(_maxFrameGap, frameGap)
	_lastProcessAtUsec = now
	if _maxFrameGap > MAX_FRAME_GAP_SECONDS:
		_fail("post-load frame gap %.3f s exceeded %.3f s while background chunks generated" % [
			_maxFrameGap, MAX_FRAME_GAP_SECONDS
		])
		return
	var backgroundElapsed := (now - _initialChunkAtUsec) / 1_000_000.0
	if backgroundElapsed >= BACKGROUND_GENERATION_TIMEOUT_SECONDS:
		_fail("background generation timed out; generated=%d, empty=%d, idle=%s" % [
			_map.generatedChunks.size(),
			_map.emptyChunks.size(),
			str(_map.idleGenerators)
		])
		return
	if not _map.emptyChunks.is_empty() or _map.idleGenerators.size() < 3:
		return
	print("CLEARWATER GROVE SCENE TEST: PASS (%d chunks generated, %d displayed cells, initial %.2f s, max post-load frame gap %.3f s)" % [
		_map.generatedChunks.size(),
		_map.get_node("Map").get_used_cells(0).size(),
		(_initialChunkAtUsec - _startedAtUsec) / 1_000_000.0,
		_maxFrameGap
	])
	get_tree().quit(0)


func _fail(message: String) -> void:
	print("CLEARWATER GROVE SCENE TEST: FAIL - ", message)
	get_tree().quit(1)
