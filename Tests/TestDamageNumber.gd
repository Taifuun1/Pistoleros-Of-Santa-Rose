extends SceneTree

## Headless smoke test for the damage number popup
## (Nodes/Damage Number/DamageNumber.tscn).
## Run with: godot --headless --script res://Tests/TestDamageNumber.gd

const DamageNumberScene = preload("res://Nodes/Damage Number/DamageNumber.tscn")

var failures = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n--- Damage number popup ---")
	var damageNumber = DamageNumberScene.instantiate()
	root.add_child(damageNumber)

	var label = damageNumber.get_node("Label")
	_check(label is RichTextLabel, "the popup renders through a RichTextLabel")
	_check(label.get_script().resource_path.ends_with("RichTextLabelExtended.gd"), "the label reuses RichTextLabelExtended")

	damageNumber.init("Miss", "red", Vector2(120, 240))
	_check(damageNumber.position == Vector2(120, 240), "the popup spawns at the given position")
	_check(label.position == Vector2.ZERO, "the label sits on the spawn point, got %s" % label.position)
	_check(not label.offset_transform_enabled, "the shared panel offset is disabled on the popup label")
	_check(label.offset_transform_position == Vector2.ZERO, "the shared panel offset is cleared, got %s" % label.offset_transform_position)
	_check(label.get_parsed_text() == "Miss", "the popup shows the label text, got %s" % label.get_parsed_text())
	_check(label.rawText.contains("#ff0000"), "the popup colors the text from the palette, got %s" % label.rawText)

	damageNumber.init("+5", "green", Vector2(0, 0))
	_check(label.get_parsed_text() == "+5", "the popup can be re-initialized, got %s" % label.get_parsed_text())
	_check(label.rawText.contains("#00ff00"), "healing numbers use the green palette entry, got %s" % label.rawText)

	var unknownColor = DamageNumberScene.instantiate()
	root.add_child(unknownColor)
	unknownColor.init("Custom", "#123456", Vector2.ZERO)
	_check(unknownColor.get_node("Label").rawText.contains("#123456"), "an unknown color key falls back to a raw BBCode color")

	damageNumber.free()
	unknownColor.free()

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
