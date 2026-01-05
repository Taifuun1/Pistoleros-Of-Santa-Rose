extends TextureRect


var card
var path
var endPosition
var duration

func init(cardData, cardName, cardPath, cardEndPosition, cardDuration):
	card = cardData
	texture = load("res://Assets/Cards/{cardName}.png".format({ "cardName": cardName }))
	path = cardPath
	endPosition = cardEndPosition
	duration = cardDuration
	hide()
