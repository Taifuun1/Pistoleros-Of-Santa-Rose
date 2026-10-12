extends Node


const TEAM_PLAYER = "player team"
const TEAM_ENEMY = "enemy team"

const ACT_TYPE_ATTACK = "Attack"
const ACT_TYPE_MOVES = "Moves"
const ACT_TYPE_ITEMS = "Items"

const RODEO_TRIGGER_FIGHT_START = "fight_start"
const RODEO_TRIGGER_FIGHT_END = "fight_end"
const RODEO_TRIGGER_ROUND_START = "round_start"
const RODEO_TRIGGER_ROUND_END = "round_end"
const RODEO_TRIGGER_TURN_START = "turn_start"
const RODEO_TRIGGER_TURN_END = "turn_end"
const RODEO_TRIGGER_ALWAYS = "always"

var shootoutPositions = {
	"player team": {
		1: Vector2i(280, 252),
		2: Vector2i(250, 252),
		3: Vector2i(220, 252),
		4: Vector2i(190, 252)
	},
	"enemy team": {
		1: Vector2i(340, 252),
		2: Vector2i(370, 252),
		3: Vector2i(400, 252),
		4: Vector2i(430, 252)
	}
}

var movesData = {}
var itemsData = {}
var rodeosData = {}


func _ready():
	loadData()

func loadData() -> void:
	movesData = loadDataFolder("res://Data/Shootout/Moves")
	itemsData = loadDataFolder("res://Data/Shootout/Items")
	rodeosData = loadDataFolder("res://Data/Shootout/Rodeos")

func loadDataFolder(folderPath: String) -> Dictionary:
	var data = {}
	for fileName in DirAccess.get_files_at(folderPath):
		if !fileName.ends_with(".gd"):
			continue
		var entry = load("{folderPath}/{fileName}".format({
			"folderPath": folderPath,
			"fileName": fileName
		})).new()
		var entryData = entry.get("data")
		if entryData != null:
			data[entryData.name] = entryData
	return data

func checkIfActorIsOnSide(actorName, actorSide, shootoutActors):
	return shootoutActors.has(actorSide) and shootoutActors[actorSide].has(actorName)
