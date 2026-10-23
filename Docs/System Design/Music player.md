# Music player

A global music player manages what tunes are being played currently. The music player needs to be always loaded, regardless of scene, so music is always managed. Things like volume controls are made later as part of a Settings management implementation. When looping or transitioning to songs in a similar zone or in a Shootout, the songs must be able to loop smoothly. There needs to be a fade before the end of the song that transitions into the next song or back to the beginning of the song.

## Music management

The music player needs to able to decide what to play based on different factors:

- What Overworld zone player is in (based on predetermined Overworld chunks)
- What Location player is in
- Shootouts based on unique encounters like quest bosses or Overworld zones
- Shops, event, menus and other UI elements that popup
- Cutscenes need to be able to manage the songs being played

## Implementation

- `Globals/MusicPlayer.gd` (autoload `MusicPlayer`, always loaded). Track ids are paths under `Assets/Music` without extension (`"Overworld/Grasslands1"`); `resolveStream` lazy-loads the OGG. Two `AudioStreamPlayer`s crossfade every switch, and each song schedules its own fade-before-end (3s tail) that blends into the next playlist song or back to the loop start; re-requesting the running playlist never restarts the song. `push_music`/`pop_music` stack popup soundtracks over the previous music. Volume controls wait for Settings.
- `Data/Music/MusicData.gd` — the decision data: Overworld zone chunk bands unifying with the zone set in Docs/Weapons and affixes.md (provisional band allocation), zone/location/menu/shootout track lists. `MusicPlayer.on_*` hooks delegate choices there.
- Hooks: `SceneManager._swapScene` calls `on_scene_changed` (main menu, locations); the overworld calls `on_overworld_chunk` on spawn and on chunk crossings (only zone changes re-switch); the Shootout scene calls `on_shootout_started` (encounter `"music"` field > per-encounter registry > encounter `"zone"` mapping > default fight list) and `on_shootout_ended` at the end screen (outcome stingers: victory / fled / vamoose / defeat, from `shootout_outcome_tracks` in MusicData); cutscenes get `on_cutscene_started` (data `"music"`) plus a non-blocking `{ "object": "music", "data": { "name": "<track id>" } }` shot; the overworld event popup pushes event data `"music"` and pops it on close.
- Tests: `Tests/TestMusicPlayer.gd` (headless, injected registry with generated silent streams) covers playback, tail fades into next song/loop, crossfades, the popup stack and every decision path.
