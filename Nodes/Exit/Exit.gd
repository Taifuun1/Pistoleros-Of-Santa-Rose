extends Area2D


@export var exitTo: Dictionary

func _ready() -> void:
	body_entered.connect($"../../..".exitLocation.bind(exitTo))
