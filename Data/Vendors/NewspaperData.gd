extends RefCounted
class_name NewspaperData

## Authored newspaper copy per Overworld Zone (Docs/System Design/Location
## Vendors Implementation.md, Newspaper data). It supplies only text: headline,
## editorial, per-encounter tips and general tips. Enemy compositions are never
## copied here — the report builder projects those from the shared encounter
## pools and actor data.

const ZoneCatalogScript = preload("res://Overworld/OverworldZoneCatalog.gd")

var zones = {
	"wild_west": {
		"zoneId": "wild_west",
		"headline": "Rats Run the Wild West Caches",
		"editorial": "Travellers out of the Wild West tell the same story: small, fast, and never alone. The vermin have learned where the caches are kept, and they do not wait for dark any more. Keep your hands where you can see them and count the teeth before you count the coin.",
		"generalTips": [
			"Everything in a pack dies easier than the pack does: thin them before you get surrounded.",
			"Scratches add up. Break line of sight and let your wounds clot.",
			"Watch the turn order strip; being last in the round is how a scratch becomes a funeral.",
		],
		"encounterTips": {
			"CanyonRats": [
				"Three of them, and all three close the distance on their own turn.",
				"Each rat has very little fight in it, so one good hit is usually enough.",
			],
			"CanyonRatNest": [
				"A full nest means four separate attackers, so expect to be outnumbered early.",
				"Rats scratch: nothing fancy, no powder, just teeth and numbers.",
			],
		},
	},
	"whispering_pines_reach": {
		"zoneId": "whispering_pines_reach",
		"headline": "Masked Bandits Waylay the Pine Roads",
		"editorial": "The pines have kept their quiet, but the roads through them have not. Hold-up crews work the treeline now: rifles from the deep columns, a taunting bull up front, and somebody in the back who dusts your eyes and your cylinder. Travel armed, travel together, and shoot the marks off you first.",
		"generalTips": [
			"Their guard loves the back columns: a rifle reaches anywhere, so closing distance does not shake him.",
			"Poison and marks stack quietly. Cleanse before you trade shots, not after.",
			"When a big man walks to the front and dares you to shoot, the whisperer behind him is the real problem.",
		],
		"encounterTips": {
			"PinesPatrol": [
				"Three revolvers, no tricks: they shoot sharp and duck when hurt.",
				"Each carries one paregoric, so a wounded Pistolero can undo your best shot.",
			],
			"PinesWaylay": [
				"Two pistols keep your front busy while the guard marks and poisons from column three.",
				"His Cylinder Drop rattles your shots; reload beats fighting a dead cylinder.",
			],
			"PinesStandoff": [
				"The bulldozer taunts and hardens his Sand — aim around him or pierce him.",
				"The rider spurs his own shots through armor; drop him before he settles in.",
				"The whisperer weakens and poisons from the rear; she barely fights, so she dies last or first, your choice.",
			],
		},
	},
}


func hasZone(zoneId: String) -> bool:
	return zones.has(zoneId)


## Deep copy of one Zone's copy, or empty when nothing is authored for it.
func getZone(zoneId: String) -> Dictionary:
	if !zones.has(zoneId):
		return {}
	return zones[zoneId].duplicate(true)


func getHeadline(zoneId: String) -> String:
	return str(getZone(zoneId).get("headline", ""))


func getEditorial(zoneId: String) -> String:
	return str(getZone(zoneId).get("editorial", ""))


func getGeneralTips(zoneId: String) -> Array:
	var tips = getZone(zoneId).get("generalTips", [])
	return tips.duplicate() if tips is Array else []


## Authored per-encounter tips, keyed by encounter file basename.
func getEncounterTips(zoneId: String, encounterId: String) -> Array:
	var tips = getZone(zoneId).get("encounterTips", {}).get(encounterId, [])
	return tips.duplicate() if tips is Array else []


## Validates the authored copy. zoneCatalog enforces canonical Zone ids;
## encounterPools, when provided, rejects tips attached to an encounter the
## Zone's shared pool does not publish.
func validate(zoneCatalog = null, encounterPools = null) -> Array:
	var errors = []
	var catalog = zoneCatalog if zoneCatalog != null else ZoneCatalogScript.new()
	for zoneId in zones:
		var zone = zones[zoneId]
		var prefix := "newspaper '%s'" % zoneId
		if !(zone is Dictionary):
			errors.append("%s must be a Dictionary" % prefix)
			continue
		if str(zone.get("zoneId", "")) != zoneId:
			errors.append("%s: zoneId must match its key" % prefix)
		if !catalog.hasZone(zoneId):
			errors.append("%s: unknown Overworld Zone id" % prefix)
		if str(zone.get("headline", "")) == "":
			errors.append("%s: missing headline" % prefix)
		if str(zone.get("editorial", "")) == "":
			errors.append("%s: missing editorial" % prefix)
		errors.append_array(_validateTips(prefix + " generalTips", zone.get("generalTips", [])))
		var encounterTips = zone.get("encounterTips", {})
		if !(encounterTips is Dictionary):
			errors.append("%s: encounterTips must be a Dictionary" % prefix)
			continue
		var published := {}
		if encounterPools != null:
			for entry in encounterPools.getPublicEntries(zoneId):
				published[str(entry.get("encounter", "")).get_file().get_basename()] = true
		var shared: Dictionary = encounterTips
		for encounterId in shared:
			errors.append_array(_validateTips("%s tips for '%s'" % [prefix, encounterId], shared[encounterId]))
			if encounterPools != null and !published.has(str(encounterId)):
				errors.append("%s: tips reference encounter '%s' that the Zone pool does not publish" % [prefix, encounterId])
	return errors


func _validateTips(prefix: String, tips) -> Array:
	var errors = []
	if !(tips is Array):
		errors.append("%s must be an Array" % prefix)
		return errors
	for index in tips.size():
		if typeof(tips[index]) != TYPE_STRING or str(tips[index]).strip_edges() == "":
			errors.append("%s entry %d must be a non-empty String" % [prefix, index])
	return errors