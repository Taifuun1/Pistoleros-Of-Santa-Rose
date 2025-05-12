extends AnimationPlayer

var cutscene

var fade = null
var playerAction = false
var wait = false


func _ready() -> void:
	initCutscene(Cutscene.cutsceneArc, Cutscene.cutsceneName)
	$AnimationPlayer.play("Fade In")

func initCutscene(cutsceneArc: String = "Pistoleros Regroup", cutsceneName: String = "Finch Pond"):
	print("res://Data/Cutscenes/{cutsceneArc}/{cutsceneName}.gd".format({ "cutsceneArc": cutsceneArc, "cutsceneName": cutsceneName.capitalize().replace(" ", "") }))
	cutscene = load("res://Data/Cutscenes/{cutsceneArc}/{cutsceneName}.gd".format({ "cutsceneArc": cutsceneArc, "cutsceneName": cutsceneName.capitalize().replace(" ", "") })).new().data
	$Setting.add_child(cutscene.setting.instantiate())

func _process(_delta):
	if !wait and !playerAction:
		advanceScene()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		$Dialog.hide()
		playerAction = false

func advanceScene():
	var scene = cutscene.shots.pop_front()
	
	if scene == null:
		get_tree().quit()
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

func _on_waiter_timeout():
	wait = false

func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	advanceScene()
