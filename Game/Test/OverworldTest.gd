extends Node2D

@export var locationScene: PackedScene


func _on_area_2d_body_entered(_body):
	get_tree().change_scene_to_packed(locationScene)
