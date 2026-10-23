extends SceneTree

## Headless validation for the world-space HP indicators (Docs/System Design/Shootout/Shootout UI.md).
## Run with: godot --headless --script res://Tests/TestHPIndicator.gd

const HPIndicatorScene = preload("res://Nodes/HP Indicator/HPIndicator.tscn")

var failures = 0


class FakeActor:

	extends Node2D
	var hp = 12
	var maxHp = 12


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n--- World-space HP indicator ---")
	var indicator = HPIndicatorScene.instantiate()
	var actor = FakeActor.new()
	root.add_child(actor)
	actor.add_child(indicator)
	indicator.init(actor)
	var fill = indicator.get_node("Fill")
	var textureWidth = fill.texture.get_width()

	_check(indicator.position == indicator.OFFSET, "the bar renders below the actor at the fixed offset")
	_check(fill.region_rect.size.x == textureWidth, "full HP shows the full fill, got %d" % fill.region_rect.size.x)
	_check(fill.modulate == Color.WHITE, "healthy actors do not tint the fill")

	actor.hp = 6
	indicator.updateHealth()
	_check(fill.region_rect.size.x == roundi(textureWidth * 0.5), "half HP halves the fill, got %d" % fill.region_rect.size.x)

	actor.hp = 0
	indicator.updateHealth()
	_check(fill.region_rect.size.x == 0, "zero HP empties the fill")
	_check(indicator.isLowHp(0, 12), "zero HP counts as low HP")

	actor.hp = 2
	indicator.updateHealth()
	_check(indicator.isLowHp(2, 12), "HP at or below the low threshold flags low HP")
	_check(fill.modulate != Color.WHITE, "low HP tints the fill")

	actor.hp = 5
	indicator.updateHealth()
	_check(!indicator.isLowHp(5, 12), "HP above the threshold does not flag low HP")
	_check(fill.modulate == Color.WHITE, "recovering above the threshold clears the tint")

	actor.maxHp = 3
	actor.hp = 2
	indicator.updateHealth()
	_check(fill.region_rect.size.x == clampi(roundi(textureWidth * 2.0 / 3.0), 0, textureWidth), "a mid-fight MxHp change rescales the bar, got %d" % fill.region_rect.size.x)

	actor.hp = 99
	actor.maxHp = 12
	indicator.updateHealth()
	_check(fill.region_rect.size.x == textureWidth, "overheal clamps the fill to the frame, got %d" % fill.region_rect.size.x)

	actor.free()

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
