extends SceneTree

## Verifies that the vertical slice's gameplay actions accept both keyboard and
## standard controller input. Run as a headless script because the bindings live
## in project settings, not scene nodes.

const MOVEMENT_ACTIONS := {
	"MOVE_UP": [11, 1],
	"MOVE_DOWN": [12, 1],
	"MOVE_LEFT": [13, 0],
	"MOVE_RIGHT": [14, 0],
}

var failures := 0


func _init() -> void:
	for action in MOVEMENT_ACTIONS:
		var buttonIndex: int = MOVEMENT_ACTIONS[action][0]
		var axisIndex: int = MOVEMENT_ACTIONS[action][1]
		_check_has_action(action)
		_check(_has_joystick_motion(action, axisIndex), "%s accepts left-stick axis %d" % [action, axisIndex])
		_check(_has_joystick_button(action, buttonIndex), "%s accepts D-pad button %d" % [action, buttonIndex])
	_check_has_action("INTERACT")
	_check(_has_joystick_button("INTERACT", 0), "INTERACT accepts the controller A button")
	_check_has_action("TOGGLE_JOURNAL")
	_check(_has_joystick_button("TOGGLE_JOURNAL", 6), "TOGGLE_JOURNAL accepts the controller Start button")
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if !condition:
		failures += 1
		printerr("CHECK FAILED: ", message)


func _check_has_action(action: String) -> void:
	_check(InputMap.has_action(action), "%s is registered" % action)
	_check(InputMap.action_get_events(action).size() >= 2, "%s has keyboard and controller events" % action)


func _has_joystick_button(action: String, buttonIndex: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and int(event.button_index) == buttonIndex:
			return true
	return false


func _has_joystick_motion(action: String, axisIndex: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and int(event.axis) == axisIndex:
			return true
	return false
