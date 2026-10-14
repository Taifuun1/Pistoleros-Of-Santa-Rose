extends Node


const TEAM_PLAYER = "player team"
const TEAM_ENEMY = "enemy team"

const ACT_TYPE_ATTACK = "Attack"
const ACT_TYPE_MOVES = "Moves"
const ACT_TYPE_ITEMS = "Items"
const ACT_TYPE_REPOSITION = "Reposition"

const RODEO_TRIGGER_FIGHT_START = "fight_start"
const RODEO_TRIGGER_FIGHT_END = "fight_end"
const RODEO_TRIGGER_ROUND_START = "round_start"
const RODEO_TRIGGER_ROUND_END = "round_end"
const RODEO_TRIGGER_TURN_START = "turn_start"
const RODEO_TRIGGER_TURN_END = "turn_end"
const RODEO_TRIGGER_ALWAYS = "always"

# Encounter launcher (Docs/System Design/Shootout/Encounters.md): callers set a
# res:// path here before switching to the Shootout scene; null falls back to
# the debug encounter.
var pendingEncounter = null

# Flavor variation names for the Shootout start popup (Docs/Combat.md).
const DUSTUP_FLAVORS = ["Scuffle", "Ruckus", "Hold-up", "Tussle"]
const SHOWDOWN_FLAVORS = ["Gunfight", "Slingin'", "High Noon", "Bangin'"]

var shootoutPositions = {
	"player team": {
		1: Vector2i(270, 222),
		2: Vector2i(240, 222),
		3: Vector2i(210, 222),
		4: Vector2i(180, 222)
	},
	"enemy team": {
		1: Vector2i(350, 222),
		2: Vector2i(380, 222),
		3: Vector2i(410, 222),
		4: Vector2i(440, 222)
	}
}

var movesData = {}
var itemsData = {}
var rodeosData = {}
var classesData = {}
var aiData = {}
var lootTablesData = {}


func _ready():
	loadData()

func loadData() -> void:
	movesData = loadDataFolder("res://Data/Shootout/Moves")
	itemsData = loadDataFolder("res://Data/Shootout/Items")
	rodeosData = loadDataFolder("res://Data/Shootout/Rodeos")
	classesData = loadDataFolder("res://Data/Shootout/Classes")
	if DirAccess.dir_exists_absolute("res://Data/Shootout/AI"):
		aiData = loadDataFolder("res://Data/Shootout/AI")
	lootTablesData = loadDataFolder("res://Data/Shootout/LootTables")

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
