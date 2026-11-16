extends Node


var data = {
	"name": "Bottle Courage Bulldozer",
	"magazine": [0, 2, 0, -1],
	"abilities": [
		"Self-increase damage type defense",
		"Self-taunt position",
		"Cylinder increase application",
		"Disrupt second and third position positioning"
	],
	"beltSpace": 1,
	"defense": { "sand": 4 },
	"explosiveBase": 0,
	"jammed": {
		"target": "self",
		"effects": [
			{ "op": "apply_effect", "effect": "decrease", "amount": 1, "turns": 1 }
		]
	}
}
