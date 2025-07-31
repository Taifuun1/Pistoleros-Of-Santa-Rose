extends Area2D


@export var cutsceneName: String

func _ready() -> void:
	body_entered.connect($"../../..".playCutscene.bind(cutsceneName))
