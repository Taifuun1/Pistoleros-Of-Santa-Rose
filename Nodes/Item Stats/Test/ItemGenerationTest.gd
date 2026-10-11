extends Control

## Interactive test scene for the item generation system
## (Globals/ItemGeneration.gd). Run this scene directly (F6) to roll items
## with adjustable parameters and see them displayed on an ItemStats node.

const ITEM_TYPES = ["", "weapon", "equipment"]
const RARITIES = ["", "common", "uncommon", "rare", "epic"]
const FAMILIES = ["", "revolver", "rifle", "shotgun"]

@onready var itemStats = $"MarginContainer/HBoxContainer/DisplayScroll/DisplayColumn/ItemStats"
@onready var infoLabel = $"MarginContainer/HBoxContainer/DisplayScroll/DisplayColumn/Info"
@onready var typeOption = $"MarginContainer/HBoxContainer/ParametersColumn/TypeOption"
@onready var rarityOption = $"MarginContainer/HBoxContainer/ParametersColumn/RarityOption"
@onready var familyOption = $"MarginContainer/HBoxContainer/ParametersColumn/FamilyOption"
@onready var zoneOption = $"MarginContainer/HBoxContainer/ParametersColumn2/ZoneOption"
@onready var generateButton = $"MarginContainer/HBoxContainer/ParametersColumn2/GenerateButton"
@onready var legendaryOption = $"MarginContainer/HBoxContainer/ParametersColumn2/LegendaryOption"
@onready var generateLegendaryButton = $"MarginContainer/HBoxContainer/ParametersColumn2/GenerateLegendaryButton"

var itemGeneration
var zoneKeys = []
var legendaryKeys = []


func _ready() -> void:
	itemGeneration = get_node_or_null("/root/ItemGeneration")
	if itemGeneration == null:
		itemGeneration = load("res://Globals/ItemGeneration.gd").new()
		add_child(itemGeneration)

	_populateOption(typeOption, ["Any", "Weapon", "Equipment"])
	_populateOption(rarityOption, ["Random", "Trail-Worn", "Serviceable", "Well-Kept", "Storied"])
	_populateOption(familyOption, ["Any", "Revolver", "Rifle", "Shotgun"])

	zoneKeys = [""] + itemGeneration.getZoneKeys()
	var zoneNames = ["Anywhere"]
	for zoneKey in itemGeneration.getZoneKeys():
		zoneNames.append(itemGeneration.equipmentData.zones[zoneKey]["displayName"])
	_populateOption(zoneOption, zoneNames)

	legendaryKeys = itemGeneration.getLegendaryKeys()
	var legendaryNames = []
	for legendaryKey in legendaryKeys:
		legendaryNames.append(itemGeneration.generateLegendary(legendaryKey)["name"])
	_populateOption(legendaryOption, legendaryNames)

	generateButton.pressed.connect(_onGeneratePressed)
	generateLegendaryButton.pressed.connect(_onGenerateLegendaryPressed)

	_onGeneratePressed()


func _populateOption(optionButton: OptionButton, entries: Array) -> void:
	optionButton.clear()
	for entry in entries:
		optionButton.add_item(str(entry))


func _onGeneratePressed() -> void:
	var options = {}
	if typeOption.selected > 0:
		options["itemType"] = ITEM_TYPES[typeOption.selected]
	if rarityOption.selected > 0:
		options["rarity"] = RARITIES[rarityOption.selected]
	if familyOption.selected > 0:
		options["family"] = FAMILIES[familyOption.selected]
	if zoneOption.selected > 0:
		options["zone"] = zoneKeys[zoneOption.selected]

	var item
	match options.get("itemType", ""):
		"weapon":
			item = itemGeneration.generateWeapon(options)
		"equipment":
			item = itemGeneration.generateEquipment(options)
		_:
			item = itemGeneration.generateItem(options)
	_display(item)


func _onGenerateLegendaryPressed() -> void:
	_display(itemGeneration.generateLegendary(legendaryKeys[legendaryOption.selected]))


func _display(item: Dictionary) -> void:
	itemStats.displayItem(item)
	var lines = []
	lines.append("Sprite: %s" % (item["sprite"] if item["sprite"] != "" else "(placeholder)"))
	if item["itemType"] == "weapon":
		lines.append("Family: %s | Damage: %d" % [item["family"], item["baseDamage"]])
	else:
		lines.append("Slot: %s | Zone: %s" % [item["slot"], item.get("zone", "anywhere")])
	for statKey in item["stats"]:
		lines.append("%s: %+d" % [statKey, item["stats"][statKey]])
	infoLabel.setRichTextLabel("\n".join(PackedStringArray(lines)))
