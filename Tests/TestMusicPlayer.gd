extends SceneTree

## Headless validation for the global music player (Docs/System Design/Music
## player.md): playback, crossfades, the fade-before-end that blends into the
## next song or the loop start, the popup push/pop stack and the context
## decisions (zones by chunk, locations, shootout encounters, cutscene data).
## Run with: godot --headless --script res://Tests/TestMusicPlayer.gd

const MusicPlayerScript = preload("res://Globals/MusicPlayer.gd")

var failures = 0


# GDScript lambdas capture locals by value, so signal counts need a
# reference-type holder.
class Counter:
	extends RefCounted
	var count = 0
	func bump(_trackId = null) -> void:
		count += 1


class FakeLocations:
	extends Node
	var currentLocation = "Lazysprings"


func makeMusicPlayer(data: Dictionary):
	var music = MusicPlayerScript.new()
	var registry = {}
	for trackId in ["a", "b", "loop", "grass", "prairie_track", "town", "menu", "fight", "boss", "zone_fight", "victory_jingle", "afterglow", "defeat_track"]:
		registry[trackId] = makeSilence(1.1)
	# Distinct lengths so tail fades wrap at different times for playlist checks.
	registry["a"] = makeSilence(0.5)
	registry["b"] = makeSilence(0.7)
	music.switchFade = 0.05
	music.tailFade = 0.2
	music.init_music(data, registry)
	root.add_child(music)
	return music


func makeData() -> Dictionary:
	return {
		"zones": [
			{ "zone": "grasslands", "min": Vector2i(0, 0), "max": Vector2i(4, 4) },
			{ "zone": "prairie", "min": Vector2i(5, 0), "max": Vector2i(9, 4) },
		],
		"default_zone": "prairie",
		"zone_tracks": { "grasslands": ["grass"], "prairie": ["prairie_track"] },
		# Both the real autoload default ("Clearwater Grove") and the fake
		# ("Lazysprings") resolve to the same track so the check holds whether
		# or not the Locations autoload exists in this run mode.
		"location_tracks": { "Lazysprings": ["town"], "Clearwater Grove": ["town"] },
		"menu_tracks": ["menu"],
		"shop_tracks": ["town"],
		"shootout_tracks": ["fight"],
		"shootout_encounter_tracks": { "Boss": ["boss"] },
		"zone_shootout_tracks": { "grasslands": ["zone_fight"] },
		"shootout_outcome_tracks": {
			"victory": ["victory_jingle", "afterglow"],
			"defeat": ["defeat_track"],
		},
	}


func makeSilence(seconds: float) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 8000
	wav.stereo = false
	var bytes = PackedByteArray()
	bytes.resize(int(seconds * wav.mix_rate) * 2)
	wav.data = bytes
	return wav


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n--- Music player ---")
	var music = makeMusicPlayer(makeData())
	var trackChanges = Counter.new()
	music.track_changed.connect(trackChanges.bump)
	await _test_play_and_tail_loop(music, trackChanges)
	await _test_playlist_transitions(music)
	await _test_crossfade_switch(music)
	await _test_push_pop_stack(music)
	_test_same_playlist_guard(music)
	_test_zone_decisions(music)
	_test_scene_decisions(music)
	_test_shootout_decisions(music)
	_test_shootout_outcome_stingers(music)
	_test_cutscene_decisions(music)
	music.free()

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


## Play a single looping track: the fade before its end blends back into the
## beginning of the same song (Docs/System Design/Music player.md).
func _test_play_and_tail_loop(music, trackChanges) -> void:
	music.play_music("loop", 0.0)
	_check(music.currentTrackId == "loop", "playing the requested track")
	_check(trackChanges.count == 1, "track_changed emitted once on play (got %d)" % trackChanges.count)
	var generationAtPlay = music.generation
	# Stream length 1.1, tail 0.2: the tail fade must fire at ~0.9s.
	await create_timer(1.15).timeout
	_check(music.generation > generationAtPlay, "the fade before the song end restarts the loop")
	_check(music.currentTrackId == "loop", "a single-track playlist loops the same song (got %s)" % music.currentTrackId)
	_check(trackChanges.count == 2, "the loop restart emits track_changed (got %d)" % trackChanges.count)
	music.stop_music(0.0)


## A playlist moves to the next track at each song's fade-before-end and wraps
## around to the first track after the last one.
func _test_playlist_transitions(music) -> void:
	music.play_music(["a", "b"], 0.0)
	_check(music.currentTrackId == "a", "the playlist starts at its first track")
	# a is 0.5 long with a 0.2 tail: switches to b at ~0.3s.
	await create_timer(0.45).timeout
	_check(music.currentTrackId == "b", "the fade before the end blends into the next song (got %s)" % music.currentTrackId)
	# b is 0.7 long: wraps back to a at ~0.3 + 0.5 = 0.8s.
	await create_timer(0.45).timeout
	_check(music.currentTrackId == "a", "after the last song the playlist wraps to the beginning (got %s)" % music.currentTrackId)
	music.stop_music(0.0)


## Switching songs crossfades: the old song fades out (and stops), the new one
## fades in to full volume.
func _test_crossfade_switch(music) -> void:
	music.play_music("loop", 0.0)
	music.play_music("b", 0.2)
	var newPlayer = music.players[music.activePlayerIndex]
	var oldPlayer = music.players[1 - music.activePlayerIndex]
	_check(oldPlayer.playing and newPlayer.playing, "both songs play during the crossfade")
	await create_timer(0.4).timeout
	_check(!oldPlayer.playing, "the previous song stops once faded out")
	_check(newPlayer.playing and absf(newPlayer.volume_db) < 0.001, "the new song reached full volume")
	music.stop_music(0.0)


## Popup music (shops, events, menus) returns to the previous song when popped.
func _test_push_pop_stack(music) -> void:
	music.play_music("loop", 0.0)
	music.push_music("town", 0.05)
	_check(music.currentTrackId == "town", "push_music plays the popup track")
	music.pop_music(0.05)
	_check(music.currentTrackId == "loop", "pop_music restores the previous track (got %s)" % music.currentTrackId)
	music.pop_music(0.0)
	music.stop_music(0.0)


## Re-requesting the playing playlist must not restart the running song.
func _test_same_playlist_guard(music) -> void:
	music.play_music(["a", "b"], 0.0)
	var generation = music.generation
	music.play_music(["a", "b"])
	_check(music.generation == generation and music.currentTrackId == "a", "the same playlist does not restart a running song")


## Zones resolve by chunk bands; only zone changes switch music.
func _test_zone_decisions(music) -> void:
	_check(music.zone_for_chunk(Vector2i(1, 3)) == "grasslands", "chunks inside a band resolve to its zone")
	_check(music.zone_for_chunk(Vector2i(99, 99)) == "prairie", "chunks outside every band fall back to the default zone")
	music.on_overworld_chunk(Vector2i(1, 3))
	_check(music.currentTrackId == "grass", "entering a zone plays its track list")
	var generation = music.generation
	music.on_overworld_chunk(Vector2i(2, 4))
	_check(music.generation == generation, "chunks within the same zone keep the song running")
	music.on_overworld_chunk(Vector2i(6, 1))
	_check(music.currentTrackId == "prairie_track", "crossing into a new zone crossfades to its track list (got %s)" % music.currentTrackId)
	music.stop_music(0.0)


## Menus and locations pick their music from the scene key.
func _test_scene_decisions(music) -> void:
	var fakeLocations = FakeLocations.new()
	fakeLocations.name = "Locations"
	root.add_child(fakeLocations)
	music.on_scene_changed("main_menu")
	_check(music.currentTrackId == "menu", "the main menu plays the menu tracks")
	music.on_scene_changed("wfc_location")
	_check(music.currentTrackId == "town", "locations play their location tracks (got %s)" % music.currentTrackId)
	fakeLocations.free()
	music.on_scene_changed("overworld")
	_check(music.currentTrackId == "town", "scenes managing their own music are untouched by the scene hook")
	music.stop_music(0.0)


## Shootout music: encounter field wins, then the registry, then the zone,
## then the default list.
func _test_shootout_decisions(music) -> void:
	music.on_shootout_started({ "name": "Whatever", "music": "boss" })
	_check(music.currentTrackId == "boss", "the encounter music field wins")
	music.on_shootout_started({ "name": "Boss" })
	_check(music.currentTrackId == "boss", "registered encounters use their registered track")
	music.on_shootout_started({ "name": "Whatever", "zone": "grasslands" })
	_check(music.currentTrackId == "zone_fight", "zone-tied fights use the zone shootout list (got %s)" % music.currentTrackId)
	music.on_shootout_started({ "name": "Whatever" })
	_check(music.currentTrackId == "fight", "unspecified fights use the default shootout list")
	music.stop_music(0.0)


## End-of-fight stingers: the outcome in the fight results picks its track;
## unmapped outcomes keep the fight music running.
func _test_shootout_outcome_stingers(music) -> void:
	music.on_shootout_started({ "name": "Whatever" })
	music.on_shootout_ended({ "outcome": "victory" })
	_check(music.currentTrackId == "victory_jingle", "a victory plays its outcome stinger (got %s)" % music.currentTrackId)
	music.on_shootout_ended({ "outcome": "defeat" })
	_check(music.currentTrackId == "defeat_track", "a defeat plays its outcome stinger (got %s)" % music.currentTrackId)
	var generation = music.generation
	music.on_shootout_ended({ "outcome": "mystery" })
	_check(music.generation == generation and music.currentTrackId == "defeat_track", "an unmapped outcome keeps the music running")
	music.stop_music(0.0)


## Cutscenes manage their own songs: data music, music shots, empty = fade out.
func _test_cutscene_decisions(music) -> void:
	music.on_cutscene_started({ "shots": [] })
	_check(music.currentTrackId == "", "cutscene data without music keeps the music stopped")
	music.on_cutscene_started({ "music": "menu" })
	_check(music.currentTrackId == "menu", "cutscene data music starts on cutscene start")
	music.on_cutscene_music_shot({ "name": "boss" })
	_check(music.currentTrackId == "boss", "music shots switch songs mid-cutscene")
	music.on_cutscene_music_shot({ "name": "" })
	_check(music.currentTrackId == "", "an empty music name fades the music out")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)