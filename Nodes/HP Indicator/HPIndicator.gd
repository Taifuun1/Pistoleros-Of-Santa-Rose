extends Node2D

## World-space HP bar for Shootout actors (Docs/System Design/Shootout/Shootout UI.md):
## a pixel frame with a left-anchored fill, rendered below the actor. HP is
## written from many call sites (action resolver, effect manager, Rodeo
## modify_stat) and actors expose no HP signals, so the bar polls its actor
## in _process and redraws only when hp/maxHp changed.

const OFFSET = Vector2(-10, 8)
const LOW_HP_FRACTION = 0.33
const LOW_HP_MODULATE = Color(1.6, 0.5, 0.5, 1)

var actor = null
var lastHp = -1
var lastMaxHp = -1


func init(actorInit) -> void:
	actor = actorInit
	position = OFFSET
	updateHealth()


func _process(_delta: float) -> void:
	updateHealth()


## Single redraw seam: reads the actor's hp/maxHp and clips the fill's region
## to the HP fraction. Region clipping (not scaling) keeps the fill pixel-crisp
## at any fraction; the bar depletes from the right because the region is
## anchored to the left edge. Null-safe for actors without hp/maxHp.
func updateHealth() -> void:
	if actor == null:
		return
	var hpValue = actor.get("hp")
	var maxHpValue = actor.get("maxHp")
	var hp = int(hpValue) if hpValue != null else 0
	var maxHp = int(maxHpValue) if maxHpValue != null else 0
	if hp == lastHp and maxHp == lastMaxHp:
		return
	lastHp = hp
	lastMaxHp = maxHp
	var fill = $Fill
	var textureWidth = fill.texture.get_width()
	var width = clampi(roundi(textureWidth * float(hp) / float(maxHp)), 0, textureWidth) if maxHp > 0 else 0
	fill.region_enabled = true
	fill.region_rect = Rect2(0, 0, width, fill.texture.get_height())
	fill.modulate = LOW_HP_MODULATE if isLowHp(hp, maxHp) else Color.WHITE


func isLowHp(hp: int, maxHp: int) -> bool:
	return maxHp > 0 and float(hp) / float(maxHp) <= LOW_HP_FRACTION
