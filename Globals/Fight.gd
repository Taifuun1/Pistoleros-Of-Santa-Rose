extends Node


var fightPositions = {
	"player team": {
		1: {
			1: Vector2i(275, 240),
			2: Vector2i(265, 252),
			3: Vector2i(255, 264)
			#4: Vector2i(260, 261)
		},
		2: {
			1: Vector2i(180, 260),
			2: Vector2i(170, 275),
			3: Vector2i(160, 290),
			4: Vector2i(150, 305)
		},
		3: {
			1: Vector2i(130, 260),
			2: Vector2i(120, 275),
			3: Vector2i(110, 290),
			4: Vector2i(100, 305)
		},
		4: {
			1: Vector2i(80, 260),
			2: Vector2i(70, 275),
			3: Vector2i(60, 290),
			4: Vector2i(50, 305)
		}
	},
	"enemy team": {
		1: {
			1: Vector2i(350, 240),
			2: Vector2i(360, 252),
			3: Vector2i(370, 264)
			#4: Vector2i(400, 265)
		},
		2: {
			1: Vector2i(410, 260),
			2: Vector2i(420, 275),
			3: Vector2i(430, 290),
			4: Vector2i(440, 305)
		},
		3: {
			1: Vector2i(490, 260),
			2: Vector2i(500, 275),
			3: Vector2i(510, 290),
			4: Vector2i(520, 305)
		},
		4: {
			1: Vector2i(540, 260),
			2: Vector2i(550, 275),
			3: Vector2i(560, 290),
			4: Vector2i(570, 305)
		}
	}
}

#var fightPositions = {
	#"player team": {
		#1: {
			#1: Vector2i(230, 260),
			#2: Vector2i(220, 275),
			#3: Vector2i(210, 290),
			#4: Vector2i(200, 305)
		#},
		#2: {
			#1: Vector2i(180, 260),
			#2: Vector2i(170, 275),
			#3: Vector2i(160, 290),
			#4: Vector2i(150, 305)
		#},
		#3: {
			#1: Vector2i(130, 260),
			#2: Vector2i(120, 275),
			#3: Vector2i(110, 290),
			#4: Vector2i(100, 305)
		#},
		#4: {
			#1: Vector2i(80, 260),
			#2: Vector2i(70, 275),
			#3: Vector2i(60, 290),
			#4: Vector2i(50, 305)
		#}
	#},
	#"enemy team": {
		#1: {
			#1: Vector2i(410, 260),
			#2: Vector2i(420, 275),
			#3: Vector2i(430, 290),
			#4: Vector2i(440, 305)
		#},
		#2: {
			#1: Vector2i(450, 260),
			#2: Vector2i(460, 275),
			#3: Vector2i(470, 290),
			#4: Vector2i(480, 305)
		#},
		#3: {
			#1: Vector2i(490, 260),
			#2: Vector2i(500, 275),
			#3: Vector2i(510, 290),
			#4: Vector2i(520, 305)
		#},
		#4: {
			#1: Vector2i(540, 260),
			#2: Vector2i(550, 275),
			#3: Vector2i(560, 290),
			#4: Vector2i(570, 305)
		#}
	#}
#}

#var abilitiesData = {
	#"columnHit": {
		#"positions": ""
	#}
#}

var itemsData = {
	"Paregoric": {
		"baseAmount": 5,
		"statScaling": 0.5,
		"side": "friendly",
		"positions": {
			"type": "single",
			"targets": {
				"columns": [1, 2, 3, 4]
			}
		}
	},
	"multiHeal": {
		"baseAmount": 1,
		"statScaling": 0.5,
		"side": "friendly",
		"positions": {
			"type": "multi",
			"shape": "column",
			"targets": {
				"columns": [1, 2, 3, 4]
			}
		}
	}
}

func checkIfActorIsOnSide(actorName, actorSide, fightActors):
	for checkedActorName in fightActors[actorSide]:
		if actorName == checkedActorName:
			return true
	return false
