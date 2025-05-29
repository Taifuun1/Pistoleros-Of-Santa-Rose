extends AnimationPlayer

var cutscene

var fade = null
var playerAction = false
var wait = true


func _ready():
	initCutscene(Cutscene.cutsceneArc, Cutscene.cutsceneName)
	initCamera(cutscene.initialCameraPosition)
	$Fade.playAnimation("Fade In")

func initCutscene(cutsceneArc: String = "Pistoleros Regroup", cutsceneName: String = "Finch Pond") -> void:
	cutscene = load("res://Data/Cutscenes/{cutsceneArc}/{cutsceneName}.gd".format({ "cutsceneArc": cutsceneArc, "cutsceneName": cutsceneName.capitalize().replace(" ", "") })).new().data
	$Setting.add_child(load("res://Location/Locations/{cutsceneArc}/{cutsceneName}/{cutsceneNameNoWhitespace}.tscn".format({ "cutsceneArc": cutsceneArc, "cutsceneName": cutsceneName, "cutsceneNameNoWhitespace": cutsceneName.capitalize().replace(" ", "") })).instantiate())
	for actorData in cutscene.actors:
		var actor = load("res://Actors/Cutscene/CutsceneActor.tscn").instantiate()
		actor.initCutsceneActor(actorData.type, actorData.name, actorData.position, false, "Idle")
		$Actors.add_child(actor)

func initCamera(position) -> void:
	$Camera2D.position = position

func _process(_delta):
	if !wait and !playerAction:
		advanceScene()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		$Dialog.hide()
		playerAction = false

func advanceScene() -> void:
	var scene = cutscene.shots.pop_front()
	
	if scene == null:
		print("fade out")
		wait = true
		$Fade.playAnimation("Fade Out")
	else:
		match scene.object:
			"dialog":
				playerAction = true
				$Dialog.setDialog(scene.data.text)
			"camera":
				$Camera2D.position = scene.data.position
			"wait":
				wait = true
				$Waiter.start(scene.data.time)

func _on_waiter_timeout() -> void:
	wait = false

func _on_fade_animation_finished(animationName: StringName) -> void:
	if animationName == "Fade Out":
		Locations.currentLocation = cutscene.nextLocation
		#Locations.currentQuest = cutscene.nextLocation
		get_tree().change_scene_to_file("res://Location/Locations/Location.tscn")
	wait = false
	advanceScene()
