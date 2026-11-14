extends RefCounted
class_name PartyMemberArt

## Pure party portrait lookup shared by the Inventory and Character tabs
## (Docs/System Design/Journal/Character.md). Party portraits follow the
## animation naming (see Shootout/UI/TurnOrderStrip.gd): actor name without the
## turn index, capitalized without spaces, plus "Icon". Missing art falls back
## to the placeholder icon.

const ICON_PATH = "res://Assets/Icons/{actorName}Icon.png"
const FALLBACK = preload("res://Assets/Icons/PlaceholderIcon.png")


static func pathForActorName(actorName: String) -> String:
	return ICON_PATH.format({
		"actorName": actorName.rstrip("0123456789").capitalize().replace(" ", "")
	})


static func textureForActorName(actorName: String) -> Texture2D:
	var iconPath = pathForActorName(actorName)
	if ResourceLoader.exists(iconPath):
		return load(iconPath)
	return FALLBACK
