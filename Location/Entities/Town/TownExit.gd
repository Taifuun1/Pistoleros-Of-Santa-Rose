extends "res://Nodes/Interaction/LocationInteractable.gd"

## Off-Trail Town exit (Docs/System Design/System Coherence.md, Trail lifecycle).
## Returns to the Overworld without starting a Trail so the party can travel
## between Towns and reach quest Locations while Off Trail. Only the explicit
## TrailDeparture starts a Trail; this marker never changes the Trail state, the
## departure counter, or vendor stock. It follows the shared door/trail marker
## convention: the marker sits on the tile the floating arrow points at, so
## returning to the Overworld stands the player on the Town's entrance tile.

const EXIT_PROMPT := "Leave town"


func _ready() -> void:
	super()
	if interactionPrompt == "Interact":
		interactionPrompt = EXIT_PROMPT


func activate() -> void:
	if !canActivate():
		return
	if Locations == null or !Locations.has_method("enterOverworld"):
		push_warning("TownExit: the authoritative Trail state is unavailable.")
		return
	if !Locations.isCurrentLocationTown():
		push_warning("TownExit: only a Town interior can use the town exit.")
		return
	# A domain command, not a Trail start: the Trail stays Off and the departure
	# counter (and therefore vendor stock) is untouched.
	Locations.enterOverworld()
	HelperFunctions.changeScene("overworld")
	activated.emit(self)
