extends Control
class_name JournalTab

## Journal tab contract (Docs/System Design/Journal/Journal.md). Tabs read
## authoritative state through domain APIs on refresh and never reach into
## Journal internals or other tabs through node paths.

const TAB_SPRITE_SCENE := preload("res://UI/Journal/TabSprite.tscn")

## The tab's icon, passed from the Journal tab registry so the icon-only tab
## strip and the tab's own content always show the same sprite.
@export var tabIcon: Texture2D = null

var active := false


func refreshTab() -> void:
	pass


func setTabActive(tabActive: bool) -> void:
	active = tabActive


func canCloseTab() -> bool:
	return true


## Centered intentional empty/unavailable state. Placeholder data must never
## be presented as live state while the tab's system is still being built.
func showStateMessage() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if tabIcon != null:
		var sprite: TabSprite = TAB_SPRITE_SCENE.instantiate() as TabSprite
		sprite.tabIcon = tabIcon
		add_child(sprite)
