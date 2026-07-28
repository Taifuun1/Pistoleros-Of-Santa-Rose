extends Node

var currentLocation = "Clearwater Grove"
var currentQuest = "Pistoleros Regroup"

var actorId = 0

var playerPosition

# Points earned from minigames, keyed by minigame name
var minigamePoints = {
	"Dodging": 0,
	"Gathering": 0,
	"Hunting": 0,
	"Mining": 0,
	"Panning": 0,
	"Robbing": 0,
}

# Materials collected during Mining and Robbing that feed into the Panning minigame
var collectedPanningMaterials = {
	"rock": 20,
	"soil": 10,
}
