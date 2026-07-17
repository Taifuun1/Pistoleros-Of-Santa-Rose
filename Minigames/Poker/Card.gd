extends TextureRect

const FACE_DOWN_TEXTURE: Texture2D = preload("res://Assets/Cards/CardDeckRed.png")
const FACE_TEXTURE_PATH := "res://Assets/Cards/Card{cardName}.png"

var card: Dictionary = {}
var endPosition := Vector2.ZERO
var duration := 0.15
var faceDown := false

func init(cardData: Dictionary, isFaceDown: bool, cardEndPosition: Vector2, cardDuration: float) -> void:
	card = cardData
	faceDown = isFaceDown
	endPosition = cardEndPosition
	duration = cardDuration
	texture = FACE_DOWN_TEXTURE if faceDown else load(_faceTexturePath())
	hide()

## Turns a face-down card face up. Does nothing for cards already face up.
func reveal() -> void:
	if not faceDown:
		return
	faceDown = false
	texture = load(_faceTexturePath())

func _faceTexturePath() -> String:
	return FACE_TEXTURE_PATH.format({ "cardName": card.name.replace(" ", "") })