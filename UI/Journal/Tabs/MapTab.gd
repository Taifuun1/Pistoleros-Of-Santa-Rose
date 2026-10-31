extends JournalTab

## Journal Overworld map tab (Docs/System Design/Journal/Overworld Map.md,
## runtime section): pan/zoom over the checked-in generated base map with
## constant-size POI/player markers. All geometry goes through the shared
## OverworldCoordinates/OverworldMapProjection; this tab never decodes
## chunks and never bakes anything. Player positions come from an injectable
## provider (the default reads the Overworld autoload's last-known spawn
## until the exact provider lands in implementation step 6); quest markers
## come from an injectable provider that returns none until the quest
## key-point API exists.

const MAP_DATA_PATH := "res://Data/Overworld/OverworldMapData.tres"
const GENERATOR_COMMAND := "godot --headless --path . --script res://Tools/GenerateOverworldMap.gd"
## Code-drawn placeholder markers; real Location/player icons are still
## pending assets, quest markers use the existing ActiveQuestIcon.
const QUEST_CURRENT_ICON := preload("res://Assets/Journal/ActiveQuestIcon.png")
const LOCATION_MARKER_COLOR := Color(0.96, 0.83, 0.55)
const PLAYER_MARKER_COLOR := Color(0.85, 0.25, 0.15)
const MARKER_PIXELS := 12
const PLAYER_REFRESH_SECONDS := 0.1
const KEYBOARD_PAN_PIXELS := 48.0
const ZOOM_STEP := 1.25
const MAX_ZOOM_FROM_FIT := 16.0

## Position provider contract: () -> { "valid": bool, "world_position":
## Vector2 (shared Overworld/MergedTiles frame), "is_live": bool }.
var positionProvider: Callable = Callable()
## Quest marker provider contract: () -> Array[{ "target_id": String
## (stable Location/key-point id), "icon": "quest_current" }].
var questMarkerProvider: Callable = Callable()
## Data path is a var so failure states can be tested without the manifest.
var mapDataPath := MAP_DATA_PATH
var mapData: OverworldMapData = null

var projection: OverworldMapProjection = null
var coordinates: OverworldCoordinates = null

var _built := false
var _view: VBoxContainer = null
var _mapClip: Control = null
var _mapContent: Control = null
var _baseMap: TextureRect = null
var _markerLayer: Control = null
var _selectionPanel: PanelContainer = null
var _selectionLabel: Label = null
var _playerMarker: TextureButton = null
var _playerPulse: Tween = null
var _refreshTimer: Timer = null
var _locationMarkers := {}
var _questMarkers := {}
var _markerTextures := {}
var _fitScale := 1.0
var _mapScale := 1.0
var _dragging := false
var _dragLastMouse := Vector2.ZERO
var _interacted := false


func refreshTab() -> void:
	if mapData == null:
		mapData = _loadMapData()
	if mapData == null:
		push_warning("Overworld map data needs regeneration; run: " + GENERATOR_COMMAND)
		_disposeView()
		showStateMessage()
		return
	if projection == null or coordinates == null:
		projection = OverworldMapProjection.new(mapData.cell_min, mapData.cell_max)
		coordinates = OverworldCoordinates.makeHeadless()
	if !_built:
		_buildView()
	_refreshQuestMarkers()
	if active:
		_startRuntime()
	_refreshPlayerMarker()


func setTabActive(tabActive: bool) -> void:
	super.setTabActive(tabActive)
	if !_built:
		return
	if tabActive:
		_startRuntime()
	else:
		_stopRuntime()


## "Show on map" navigation request: selects, centers and pulses the target
## marker without altering quest state.
func focusTarget(targetId: String) -> void:
	if !_built:
		return
	var marker: TextureButton = _locationMarkers.get(targetId)
	var kind := "Location"
	if marker == null:
		marker = _questMarkers.get(targetId)
		kind = "Quest target"
	if marker == null:
		return
	_centerOnImagePosition(marker.get_meta("image_position"))
	_selectMarker(marker, kind)


func _loadMapData() -> OverworldMapData:
	if !ResourceLoader.exists(mapDataPath):
		return null
	var data = load(mapDataPath)
	if data == null or !(data is OverworldMapData):
		return null
	if data.format_version != OverworldMapData.FORMAT_VERSION or data.texture == null:
		return null
	var mapProjection := OverworldMapProjection.new(data.cell_min, data.cell_max)
	if mapProjection.imageSize != data.image_size:
		return null
	return data


## Default player position until the exact provider lands: the Overworld
## autoload's last-known spawn anchor. The autoload is resolved by path so
## this script stays loadable without project autoloads (headless tests).
func _defaultPositionProvider() -> Dictionary:
	if !is_inside_tree():
		return { "valid": false, "world_position": Vector2.ZERO, "is_live": false }
	var overworldAutoload = get_tree().root.get_node_or_null("Overworld")
	if overworldAutoload == null or coordinates == null:
		return { "valid": false, "world_position": Vector2.ZERO, "is_live": false }
	var worldPosition: Vector2 = coordinates.chunkTileToWorld(overworldAutoload.spawnChunk, overworldAutoload.spawnTile)
	return { "valid": true, "world_position": worldPosition, "is_live": false }


func _defaultQuestMarkerProvider() -> Array:
	return []


func _resolvePositionProvider() -> Callable:
	return positionProvider if positionProvider.is_valid() else Callable(self, "_defaultPositionProvider")


func _resolveQuestMarkerProvider() -> Callable:
	return questMarkerProvider if questMarkerProvider.is_valid() else Callable(self, "_defaultQuestMarkerProvider")


## The map view is built in code once from the manifest; repeated activations
## refresh only markers (never duplicates). Structure per the map doc:
## MapControls over MapClip(MapContent(BaseMap, MarkerLayer)) plus a
## selection panel.
func _buildView() -> void:
	_disposeView()
	_view = VBoxContainer.new()
	_view.name = "MapView"
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_view)

	var controls := HBoxContainer.new()
	controls.name = "MapControls"
	controls.add_theme_constant_override("separation", 4)
	_view.add_child(controls)
	_addControlButton(controls, "-", "Zoom out", _zoomOut)
	_addControlButton(controls, "+", "Zoom in", _zoomIn)
	_addControlButton(controls, "Fit", "Fit the whole map", _fitMap)
	_addControlButton(controls, "Center", "Center on the player", _centerOnPlayer)

	_mapClip = Control.new()
	_mapClip.name = "MapClip"
	_mapClip.clip_contents = true
	_mapClip.focus_mode = Control.FOCUS_ALL
	_mapClip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mapClip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mapClip.gui_input.connect(_onMapClipGuiInput)
	_mapClip.resized.connect(_onMapClipResized)
	_view.add_child(_mapClip)

	_mapContent = Control.new()
	_mapContent.name = "MapContent"
	_mapClip.add_child(_mapContent)

	_baseMap = TextureRect.new()
	_baseMap.name = "BaseMap"
	_baseMap.texture = mapData.texture
	_mapContent.add_child(_baseMap)

	_markerLayer = Control.new()
	_markerLayer.name = "MarkerLayer"
	_mapContent.add_child(_markerLayer)

	_selectionPanel = PanelContainer.new()
	_selectionPanel.name = "SelectionPanel"
	_selectionPanel.anchor_left = 0.5
	_selectionPanel.anchor_right = 0.5
	_selectionPanel.anchor_top = 1.0
	_selectionPanel.anchor_bottom = 1.0
	_selectionPanel.offset_left = -80
	_selectionPanel.offset_right = 80
	_selectionPanel.offset_top = -22
	_selectionPanel.offset_bottom = -6
	_selectionPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mapClip.add_child(_selectionPanel)
	_selectionLabel = Label.new()
	_selectionLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selectionPanel.add_child(_selectionLabel)
	_selectionPanel.visible = false

	_refreshTimer = Timer.new()
	_refreshTimer.wait_time = PLAYER_REFRESH_SECONDS
	_refreshTimer.timeout.connect(_refreshPlayerMarker)
	add_child(_refreshTimer)

	for location in mapData.locations:
		_addLocationMarker(location)
	_playerMarker = _addMarker(_markerTexture("player"), Vector2.ZERO, "Last known position")
	_playerMarker.visible = false
	_built = true
	_interacted = false
	_fitMap.call_deferred()


func _addControlButton(parent: Control, text: String, tooltip: String, handler: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	# Map shortcut buttons never join keyboard/controller focus traversal:
	# arrows must stay map panning, not hop between controls. The same keys
	# (and wheel/mouse) fully operate the map, so nothing is lost.
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(handler)
	parent.add_child(button)


func _addLocationMarker(location: Dictionary) -> void:
	var marker := _addMarker(_markerTexture("location"), location["image_position"], location["display_name"])
	marker.pressed.connect(_selectMarker.bind(marker, "Location"))
	_locationMarkers[location["id"]] = marker


func _addMarker(texture: Texture2D, imagePosition: Vector2, tooltip: String) -> TextureButton:
	var marker := TextureButton.new()
	marker.texture_normal = texture
	# Markers are mouse targets only; arrow traversal stays on the map itself.
	marker.focus_mode = Control.FOCUS_NONE
	marker.tooltip_text = tooltip
	marker.set_meta("image_position", imagePosition)
	_markerLayer.add_child(marker)
	_layoutMarker(marker)
	return marker


## Markers keep a constant screen size: they sit at image coordinates inside
## the scaled MapContent and are counter-scaled, anchored bottom-center on
## their projected position (their texture never affects world coordinates).
func _layoutMarker(marker: TextureButton) -> void:
	var markerScale := 1.0 / _mapScale
	marker.scale = Vector2(markerScale, markerScale)
	var textureSize: Vector2 = marker.texture_normal.get_size()
	var imagePosition: Vector2 = marker.get_meta("image_position")
	marker.position = imagePosition - Vector2(textureSize.x * markerScale * 0.5, textureSize.y * markerScale)


func _applyMarkerTransforms() -> void:
	for marker in _markerLayer.get_children():
		_layoutMarker(marker)


func _markerTexture(kind: String) -> Texture2D:
	if _markerTextures.has(kind):
		return _markerTextures[kind]
	if kind == "quest_current":
		_markerTextures[kind] = QUEST_CURRENT_ICON
		return QUEST_CURRENT_ICON
	var color := LOCATION_MARKER_COLOR
	if kind == "player":
		color = PLAYER_MARKER_COLOR
	var image := Image.create(MARKER_PIXELS, MARKER_PIXELS, false, Image.FORMAT_RGBA8)
	for y in MARKER_PIXELS:
		for x in MARKER_PIXELS:
			if absf(x - 5.5) + absf(y - 5.5) <= 5.9:
				image.set_pixel(x, y, color)
	_markerTextures[kind] = ImageTexture.create_from_image(image)
	return _markerTextures[kind]


func _disposeView() -> void:
	if _view != null:
		_view.queue_free()
	_view = null
	_mapClip = null
	_mapContent = null
	_baseMap = null
	_markerLayer = null
	_selectionPanel = null
	_selectionLabel = null
	_playerMarker = null
	_refreshTimer = null
	_locationMarkers = {}
	_questMarkers = {}
	_playerPulse = null
	_built = false


func _startRuntime() -> void:
	if _refreshTimer != null:
		_refreshTimer.start()
	if _playerMarker != null and _playerPulse == null:
		_playerPulse = create_tween().set_loops()
		_playerPulse.tween_property(_playerMarker, "modulate:a", 0.55, 0.8).from(1.0).set_trans(Tween.TRANS_SINE)


func _stopRuntime() -> void:
	if _refreshTimer != null:
		_refreshTimer.stop()
	if _playerPulse != null:
		_playerPulse.kill()
		_playerPulse = null
	if _playerMarker != null:
		_playerMarker.modulate.a = 1.0


func _selectMarker(marker: TextureButton, kind: String) -> void:
	if _selectionPanel == null:
		return
	_selectionLabel.text = "{kind}: {name}".format({ "kind": kind, "name": marker.tooltip_text })
	_selectionPanel.visible = true


## Player marker: world position -> cell fraction -> image position, through
## the same projection the bake used. Hidden when no valid position exists;
## never defaulted to a corner.
func _refreshPlayerMarker() -> void:
	if !_built or _playerMarker == null or _markerLayer == null:
		return
	var positionResult: Dictionary = _resolvePositionProvider().call()
	if !positionResult.get("valid", false):
		_playerMarker.visible = false
		return
	var worldPosition: Vector2 = positionResult.get("world_position", Vector2.ZERO)
	_playerMarker.tooltip_text = "Current position" if positionResult.get("is_live", false) else "Last known position"
	_playerMarker.set_meta("image_position", projection.cellFractionToImage(coordinates.worldToCellFraction(worldPosition)))
	_playerMarker.visible = true
	_layoutMarker(_playerMarker)


## Quest markers resolve only through the generated manifest; unknown or
## inactive targets warn and never appear at (0,0).
func _refreshQuestMarkers() -> void:
	if !_built or _markerLayer == null:
		return
	for marker in _questMarkers.values():
		marker.queue_free()
	_questMarkers = {}
	var questMarkers: Array = _resolveQuestMarkerProvider().call()
	for questMarker in questMarkers:
		var targetId := str(questMarker.get("target_id", ""))
		var location := mapData.resolveLocation(targetId)
		if location.is_empty():
			push_warning("Overworld map: quest target '{target}' has no manifest entry".format({ "target": targetId }))
			continue
		var marker := _addMarker(_markerTexture("quest_current"), location["image_position"], location["display_name"])
		marker.pressed.connect(_selectMarker.bind(marker, "Quest target"))
		_questMarkers[targetId] = marker


func _fitMap() -> void:
	if _mapClip == null or mapData == null:
		return
	var clipSize := _mapClip.size
	if clipSize.x <= 0.0 or clipSize.y <= 0.0:
		return
	var imageSize := Vector2(mapData.image_size)
	_fitScale = minf(clipSize.x / imageSize.x, clipSize.y / imageSize.y)
	_mapScale = _fitScale
	_mapContent.scale = Vector2(_mapScale, _mapScale)
	_mapContent.position = (clipSize - imageSize * _mapScale) * 0.5
	_clampPan()
	_applyMarkerTransforms()
	_interacted = false


## Zoom around a screen-space anchor point so the point under the cursor or
## focus stays put.
func _setMapScale(newScale: float, anchorScreenPosition: Vector2) -> void:
	if _mapContent == null or mapData == null or _fitScale <= 0.0:
		return
	newScale = clampf(newScale, _fitScale, _fitScale * MAX_ZOOM_FROM_FIT)
	if is_equal_approx(newScale, _mapScale):
		return
	var anchorImage := (anchorScreenPosition - _mapContent.position) / _mapScale
	_mapScale = newScale
	_mapContent.scale = Vector2(_mapScale, _mapScale)
	_mapContent.position = anchorScreenPosition - anchorImage * _mapScale
	_clampPan()
	_applyMarkerTransforms()


func _zoomAt(screenPosition: Vector2, factor: float) -> void:
	_interacted = true
	_setMapScale(_mapScale * factor, screenPosition)


func _zoomIn() -> void:
	if _mapClip != null:
		_zoomAt(_mapClip.size * 0.5, ZOOM_STEP)


func _zoomOut() -> void:
	if _mapClip != null:
		_zoomAt(_mapClip.size * 0.5, 1.0 / ZOOM_STEP)


func _panBy(screenDelta: Vector2) -> void:
	if _mapContent == null:
		return
	_interacted = true
	_mapContent.position += screenDelta
	_clampPan()


## Pan clamp: the map's edges can always be reached, but no direction pans
## past them into empty space.
func _clampPan() -> void:
	if _mapClip == null or _mapContent == null or mapData == null:
		return
	var clipSize := _mapClip.size
	var mapSize := Vector2(mapData.image_size) * _mapScale
	var minX := minf(0.0, clipSize.x - mapSize.x)
	var maxX := maxf(0.0, clipSize.x - mapSize.x)
	var minY := minf(0.0, clipSize.y - mapSize.y)
	var maxY := maxf(0.0, clipSize.y - mapSize.y)
	_mapContent.position = Vector2(
		clampf(_mapContent.position.x, minX, maxX),
		clampf(_mapContent.position.y, minY, maxY)
	)


## "Center player" switches to a useful close zoom on the marker.
func _centerOnImagePosition(imagePosition: Vector2) -> void:
	if _mapClip == null or _mapContent == null:
		return
	_interacted = true
	_setMapScale(clampf(_fitScale * 6.0, _fitScale, _fitScale * MAX_ZOOM_FROM_FIT), _mapClip.size * 0.5)
	_mapContent.position = _mapClip.size * 0.5 - imagePosition * _mapScale
	_clampPan()
	_applyMarkerTransforms()


func _centerOnPlayer() -> void:
	if _playerMarker == null or !_playerMarker.visible:
		_fitMap()
		return
	_centerOnImagePosition(_playerMarker.get_meta("image_position"))


func _onMapClipResized() -> void:
	if _built and !_interacted:
		_fitMap()


## Map input stays on the map: the wheel zooms at the cursor and the focused
## clip pans with the arrows; everything is consumed so nothing leaks to the
## Journal's tab shortcuts. Mouse drag panning is NOT handled here — grabbed
## press/motion delivery is unreliable across engine grab semantics, so
## _pollDragPan drives it from _process instead.
func _onMapClipGuiInput(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var buttonEvent := event as InputEventMouseButton
		if buttonEvent.pressed and buttonEvent.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoomAt(buttonEvent.position, ZOOM_STEP)
			_mapClip.accept_event()
		elif buttonEvent.pressed and buttonEvent.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoomAt(buttonEvent.position, 1.0 / ZOOM_STEP)
			_mapClip.accept_event()
	elif event is InputEventKey and event.is_pressed() and !event.is_echo():
		if _handleMapKey(event as InputEventKey):
			_mapClip.accept_event()


func _handleMapKey(keyEvent: InputEventKey) -> bool:
	if keyEvent.is_action_pressed("ui_left"):
		_panBy(Vector2(KEYBOARD_PAN_PIXELS, 0))
	elif keyEvent.is_action_pressed("ui_right"):
		_panBy(Vector2(-KEYBOARD_PAN_PIXELS, 0))
	elif keyEvent.is_action_pressed("ui_up"):
		_panBy(Vector2(0, KEYBOARD_PAN_PIXELS))
	elif keyEvent.is_action_pressed("ui_down"):
		_panBy(Vector2(0, -KEYBOARD_PAN_PIXELS))
	elif keyEvent.keycode == KEY_F:
		_fitMap()
	elif keyEvent.keycode == KEY_C:
		_centerOnPlayer()
	else:
		return false
	return true


## Keyboard fallback when focus sits outside the map (nothing focused, or the
## shell's TabBar which consumes arrows for tab switching itself): still
## unhandled map keys drive the map. Runs after gui_input, so the focused
## MapClip path never double-applies.
func _unhandled_key_input(event: InputEvent) -> void:
	if !_built or !active or !is_visible_in_tree():
		return
	if event is InputEventKey and event.is_pressed() and !event.is_echo() \
			and _handleMapKey(event as InputEventKey):
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _built and active and is_visible_in_tree():
		_pollDragPan()


## Mouse drag pans by polling the cursor each frame instead of relying on
## grabbed press/motion gui_input delivery: arming on "left held over the map"
## keeps working when the press was consumed by a child (markers) or by
## engine grab semantics, and keeps dragging while the cursor leaves the clip.
func _pollDragPan() -> void:
	var mousePosition: Vector2 = _mapClip.get_global_mouse_position()
	var held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if !_dragging:
		if held and _mapClip.get_global_rect().has_point(mousePosition):
			_dragging = true
			_dragLastMouse = mousePosition
		return
	if !held:
		_dragging = false
		return
	_panBy(mousePosition - _dragLastMouse)
	_dragLastMouse = mousePosition
