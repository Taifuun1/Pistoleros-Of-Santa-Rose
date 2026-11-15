extends Area2D

## Proximity interaction target for Locations and vendor rooms
## (Docs/System Design/Location Vendors Implementation.md, patch 3). The target
## only tracks whether the grouped location player is overlapping; the scene's
## LocationInteractionDirector decides which target is closest and activates it.

signal activated(target)

@export var interactionPrompt := "Interact"
@export var enabled := true

var playerNearby := false
var playerActor: Node2D = null


func _ready() -> void:
	add_to_group("location_interactables")
	if !body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if !body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body != null and body.is_in_group("location_player"):
		playerNearby = true
		playerActor = body as Node2D


func _on_body_exited(body: Node) -> void:
	if body == playerActor:
		playerNearby = false
		playerActor = null


func canActivate() -> bool:
	return enabled and playerNearby


func activate() -> void:
	if !canActivate():
		return
	activated.emit(self)


## Distance used by the director's closest-target selection. Missing/invalid
## players sort last instead of producing an error.
func distanceToPlayer() -> float:
	if playerActor == null or !is_instance_valid(playerActor):
		return INF
	return global_position.distance_to(playerActor.global_position)
