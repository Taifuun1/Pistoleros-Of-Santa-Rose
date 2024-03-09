extends AnimationPlayer

@onready var dialog = preload("res://Data/Dialog/Test/TestDialog.gd").new()

var playerAction = false
var wait = false


func _ready():
	advanceScene()

func _process(_delta):
	if !wait and !playerAction:
		advanceScene()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		$Dialog.hide()
		playerAction = false

func advanceScene():
	var scene = dialog.data.shots.pop_front()
	
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
