extends Node

## Global music player (Docs/System Design/Music player.md). Always loaded as
## an autoload so music keeps playing across scene changes. Track ids are the
## paths under Assets/Music without extension ("Overworld/Grasslands1"); the
## what-to-play decisions come from Data/Music/MusicData.gd (zones, locations,
## encounters, menus). Every switch crossfades (a switch from a silent state
## begins the new song at full volume instead of fading in), and each song
## fades out shortly before its end, blending into the next song of the
## playlist or back to the beginning of the loop. Volume controls arrive with
## the Settings implementation; everything plays on the Master bus.

signal track_changed(trackId)

const MUSIC_ROOT = "res://Assets/Music"
const MUSIC_DATA_SCRIPT = "res://Data/Music/MusicData.gd"

# Fade used when switching music (scene change, zone change, popups).
const DEFAULT_SWITCH_FADE = 1.5
# The tail of each song that fades out into the next song (or the loop start).
const DEFAULT_TAIL_FADE = 3.0
const SILENT_VOLUME_DB = -60.0

# Registry: trackId -> file path. Injectable for tests (entries there may also
# be pre-built AudioStreams).
var tracks = {}
# Mappings from Data/Music/MusicData.gd. Injectable for tests.
var musicData = {}

var switchFade = DEFAULT_SWITCH_FADE
var tailFade = DEFAULT_TAIL_FADE

# Playback state.
var playlist = []
var playlistIndex = 0
var currentTrackId = ""
var currentZone = ""
# Popup stacks: playlists pushed by UI popups, restored by pop_music.
var musicStack = []

# Internals: two players crossfading, plus one scheduled fade-before-end per
# song. A generation counter invalidates timers from stale songs.
var players = []
var activePlayerIndex = 0
var generation = 0
var volumeTweens = {}


func _ready() -> void:
	for i in 2:
		var player = AudioStreamPlayer.new()
		player.name = "Player{index}".format({ "index": i })
		player.volume_db = SILENT_VOLUME_DB
		add_child(player)
		players.append(player)
	if musicData.is_empty() and ResourceLoader.exists(MUSIC_DATA_SCRIPT):
		musicData = load(MUSIC_DATA_SCRIPT).new().data
	if tracks.is_empty():
		_scanMusicFolder(MUSIC_ROOT, "")


## Test/override seam: inject the mapping data and the track registry instead
## of loading MusicData / scanning the music folders.
func init_music(data: Dictionary, trackRegistry: Dictionary) -> void:
	musicData = data
	tracks = trackRegistry


# ── Registry ─────────────────────────────────────────────────────────────────

## Every .ogg under Assets/Music becomes a track id: relative path without
## extension ("Shootout/Dusty Showdown", "Thematic/Chill/Chill1").
func _scanMusicFolder(folderPath: String, prefix: String) -> void:
	for fileName in DirAccess.get_files_at(folderPath):
		if fileName.ends_with(".ogg"):
			tracks[prefix + fileName.get_basename()] = folderPath + "/" + fileName
	for dirName in DirAccess.get_directories_at(folderPath):
		_scanMusicFolder(folderPath + "/" + dirName, prefix + dirName + "/")


func resolveStream(trackId: String):
	var entry = tracks.get(trackId, null)
	if entry is AudioStream:
		return entry
	if entry is String and ResourceLoader.exists(entry):
		return load(entry)
	if entry != null:
		push_warning("MusicPlayer: could not resolve track '{trackId}'".format({ "trackId": trackId }))
	return null


# ── Playback ─────────────────────────────────────────────────────────────────

## Plays a track id or a list of track ids (looped), crossfading from whatever
## was playing. An empty selection fades the music out.
func play_music(trackSelection, fadeSeconds := -1.0) -> void:
	var ids = _selectionToIds(trackSelection)
	if ids.is_empty():
		stop_music(fadeSeconds)
		return
	# Never restart the playlist that is already playing (zone churn and
	# repeated scene entries must not cut a running song).
	if _currentPlaylistIs(ids):
		return
	_startPlaylist(ids, 0, _fadeSeconds(fadeSeconds))


func stop_music(fadeSeconds := -1.0) -> void:
	generation += 1
	currentTrackId = ""
	playlist = []
	playlistIndex = 0
	_fadeOutPlayer(players[activePlayerIndex], _fadeSeconds(fadeSeconds))


## Popup soundtrack (shops, events, menus that appear over other scenes):
## plays a temporary track selection and restores the previous music on pop.
func push_music(trackSelection, fadeSeconds := -1.0) -> void:
	musicStack.append({ "playlist": playlist.duplicate(), "index": playlistIndex })
	play_music(trackSelection, fadeSeconds)


func pop_music(fadeSeconds := -1.0) -> void:
	if musicStack.is_empty():
		push_warning("MusicPlayer: pop_music with an empty music stack")
		return
	var restored = musicStack.pop_back()
	if restored.playlist.is_empty():
		stop_music(fadeSeconds)
	else:
		_startPlaylist(restored.playlist, restored.index, _fadeSeconds(fadeSeconds))


func _startPlaylist(list: Array, startIndex: int, fadeSeconds: float) -> void:
	# Skip unresolvable ids so one bad entry can never silence the playlist.
	var resolvedIndex = -1
	var stream = null
	for i in list.size():
		var candidate = (startIndex + i) % list.size()
		stream = resolveStream(list[candidate])
		if stream != null:
			resolvedIndex = candidate
			break
		stream = null
	if stream == null:
		push_warning("MusicPlayer: no playable track in the given selection")
		return
	playlist = list.duplicate()
	playlistIndex = resolvedIndex
	currentTrackId = str(list[resolvedIndex])
	generation += 1
	_crossfadeTo(stream, fadeSeconds)
	_scheduleTailFade(stream)
	track_changed.emit(currentTrackId)


## Two players fading into each other; the previous song keeps playing while
## the new one fades in (or swaps instantly at fade 0). A fade-in only blends
## an actually audible song: when nothing is playing at volume (a scene
## transition, the first launch of the game, a stop_music just before this
## call), the new track starts at full volume instead of fading in from
## silence (Docs/Features and Issues.md).
func _crossfadeTo(stream: AudioStream, fadeSeconds: float) -> void:
	var nextIndex = 1 - activePlayerIndex
	var nextPlayer = players[nextIndex]
	var previousPlayer = players[activePlayerIndex]
	nextPlayer.stream = stream
	# Anything at (or below) the silent volume fades together with nothing;
	# treat it as silence so the new song begins at full strength.
	var previousIsAudible = previousPlayer.playing and previousPlayer.volume_db > SILENT_VOLUME_DB
	var fadeIn = fadeSeconds > 0.0 and previousIsAudible
	nextPlayer.volume_db = SILENT_VOLUME_DB if fadeIn else 0.0
	nextPlayer.play()
	if fadeIn:
		_tweenVolume(nextPlayer, 0.0, fadeSeconds)
	_fadeOutPlayer(previousPlayer, fadeSeconds)
	activePlayerIndex = nextIndex


func _fadeOutPlayer(player: AudioStreamPlayer, fadeSeconds: float) -> void:
	if !player.playing:
		return
	_tweenVolume(player, SILENT_VOLUME_DB, fadeSeconds, true)


func _tweenVolume(player: AudioStreamPlayer, targetDb: float, fadeSeconds: float, stopAtEnd := false) -> void:
	var tweenKey = player.name
	if volumeTweens.has(tweenKey):
		volumeTweens[tweenKey].kill()
	if fadeSeconds <= 0.0:
		player.volume_db = targetDb
		if stopAtEnd:
			player.stop()
		return
	var tween = create_tween()
	tween.tween_property(player, "volume_db", targetDb, fadeSeconds)
	if stopAtEnd:
		tween.finished.connect(player.stop)
	volumeTweens[tweenKey] = tween


## The fade before the end of the song (Docs/System Design/Music player.md):
## once only a tailFade-long stretch remains, crossfade into the next song of
## the playlist or back to the beginning of the loop.
func _scheduleTailFade(stream: AudioStream) -> void:
	var scheduledGeneration = generation
	var remaining = maxf(0.1, stream.get_length() - tailFade)
	get_tree().create_timer(remaining).timeout.connect(func():
		if scheduledGeneration != generation:
			return
		_startPlaylist(playlist, (playlistIndex + 1) % playlist.size(), tailFade)
	)


# ── Decisions (Docs/System Design/Music player.md, Data/Music/MusicData.gd) ──

## Called by the scene manager once a scene switch applied its context. The
## overworld, shootouts and cutscenes drive their own music through their
## dedicated handlers (zone chunks, encounter data, cutscene shots).
func on_scene_changed(sceneKey: String) -> void:
	match sceneKey:
		"main_menu":
			play_music(menu_tracks())
		"location", "pregenerated_location", "wfc_location":
			var locations = get_node_or_null("/root/Locations")
			if locations == null:
				return
			play_music(location_tracks(str(locations.get("currentLocation"))))
		_:
			pass


## Hooked by the overworld whenever the player enters a new chunk: the chunk
## resolves to a zone through the bands in MusicData, and only an actual zone
## change restarts the music.
func on_overworld_chunk(chunk: Vector2i) -> void:
	var zone = zone_for_chunk(chunk)
	if zone == currentZone:
		return
	currentZone = zone
	play_music(zone_tracks(zone))


## Shootout music: the encounter's own "music" field first (unique encounters
## like quest bosses), then the per-encounter registry, then the "zone" field
## (fights tied to an Overworld zone), then the default shootout list.
func on_shootout_started(encounterData: Dictionary) -> void:
	var encounterMusic = str(encounterData.get("music", ""))
	if encounterMusic != "":
		play_music(encounterMusic)
		return
	var encounterName = str(encounterData.get("name", ""))
	var perEncounter: Dictionary = musicData.get("shootout_encounter_tracks", {})
	if perEncounter.has(encounterName):
		play_music(perEncounter[encounterName])
		return
	var fightZone = str(encounterData.get("zone", ""))
	var perZone: Dictionary = musicData.get("zone_shootout_tracks", {})
	if perZone.has(fightZone):
		play_music(perZone[fightZone])
		return
	play_music(shootout_tracks())


## End-of-fight stingers for the Shootout end screen (Docs/System Design/Music
## player.md): the fight results' "outcome" (victory / fled / vamoose / defeat)
## picks its track list from MusicData; unmapped outcomes leave the fight
## music running until the scene changes.
func on_shootout_ended(fightResults: Dictionary) -> void:
	var outcome = str(fightResults.get("outcome", ""))
	var stingers: Dictionary = musicData.get("shootout_outcome_tracks", {})
	if stingers.has(outcome):
		play_music(stingers[outcome])


## Cutscenes manage their own songs: the cutscene data may start one with its
## "music" field, and "music" shots change songs while it plays. Without
## either, whatever is playing simply continues under the cutscene.
func on_cutscene_started(cutsceneData: Dictionary) -> void:
	var cutsceneMusic = str(cutsceneData.get("music", ""))
	if cutsceneMusic != "":
		play_music(cutsceneMusic)


## Cutscene shot handler: { "object": "music", "data": { "name": "<track id>" } }.
## An empty name fades the music out.
func on_cutscene_music_shot(shotData: Dictionary) -> void:
	var trackName = str(shotData.get("name", ""))
	if trackName == "":
		stop_music()
	else:
		play_music(trackName)


func menu_tracks() -> Array:
	return musicData.get("menu_tracks", [])


func shop_tracks() -> Array:
	return musicData.get("shop_tracks", [])


func zone_tracks(zone: String) -> Array:
	return musicData.get("zone_tracks", {}).get(zone, [])


func location_tracks(locationName: String) -> Array:
	return musicData.get("location_tracks", {}).get(locationName, [])


func shootout_tracks() -> Array:
	return musicData.get("shootout_tracks", [])


## The zone of an Overworld chunk: the first inclusive "min"/"max" corner band
## containing it wins; anything outside falls back to the default zone.
func zone_for_chunk(chunk: Vector2i) -> String:
	for band in musicData.get("zones", []):
		if (
			chunk.x >= int(band.min.x) and chunk.x <= int(band.max.x)
			and chunk.y >= int(band.min.y) and chunk.y <= int(band.max.y)
		):
			return str(band.zone)
	return str(musicData.get("default_zone", ""))


# ── Helpers ──────────────────────────────────────────────────────────────────

func _selectionToIds(trackSelection) -> Array:
	var ids = []
	if trackSelection is Array:
		for entry in trackSelection:
			ids.append(str(entry))
	elif trackSelection != null and str(trackSelection) != "":
		ids.append(str(trackSelection))
	return ids


func _currentPlaylistIs(ids: Array) -> bool:
	if playlist.is_empty() or playlist.size() != ids.size():
		return false
	for i in ids.size():
		if str(playlist[i]) != str(ids[i]):
			return false
	return true


func _fadeSeconds(requested: float) -> float:
	return switchFade if requested < 0.0 else requested
