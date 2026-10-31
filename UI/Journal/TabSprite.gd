extends TextureRect
class_name TabSprite

## Reusable icon-only Journal tab sprite (Journal.md visual direction): just
## the tab's icon, never any text. The tab strip and tab empty states share
## it so a tab is always identified by the same sprite.

@export var tabId := ""

@export var tabIcon: Texture2D = null:
	set(value):
		tabIcon = value
		texture = value
