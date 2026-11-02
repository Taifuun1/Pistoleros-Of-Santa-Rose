extends Node2D


var playCutsceneNext = false

func initLocation() -> void:
	if get_node_or_null("Cutscenes"):
		for cutsceneNode in $Cutscenes.get_children():
			if Cutscene.playedCutscenes.get(str(cutsceneNode.name), false):
				for cutsceneArea in cutsceneNode.get_children():
					cutsceneArea.monitoring = false
	var player = load("res://Actors/Location/PlayerLocationActor.tscn").instantiate()
	player.position = Locations.currentLocation.playerPosition
	add_child(player)
	$Fade.play("Fade In")

func playCutscene(_body: Node2D, cutsceneName: StringName):
	Cutscene.cutsceneName = str(cutsceneName)
	playCutsceneNext = true
	Cutscene.playedCutscenes[str(cutsceneName)] = true
	$Fade.play("Fade Out")

func exitLocation(_body: Node2D, exitTo: Dictionary) -> void:
	Locations.currentLocation = exitTo
	$Fade.play("Fade Out")


func _on_fade_animation_finished(animationName: StringName) -> void:
	if animationName == "Fade Out":
		if playCutsceneNext:
			HelperFunctions.changeScene("cutscene")
			return
		HelperFunctions.changeScene("location")
