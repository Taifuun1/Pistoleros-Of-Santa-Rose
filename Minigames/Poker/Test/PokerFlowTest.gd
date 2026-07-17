extends Node

const MAX_GAMES := 5
const MAX_FRAMES := 60 * 60 * 4

var poker
var gamesPlayed := 0
var frames := 0
var totalMoney := 0
var failed := false
var wasGameActive := false

func _ready() -> void:
	poker = load("res://Minigames/Poker/Poker.tscn").instantiate()
	add_child(poker)
	for playerName in poker.players:
		totalMoney += poker.players[playerName].money
	await get_tree().process_frame
	poker.startGame()
	wasGameActive = true

func _process(_delta: float) -> void:
	frames += 1
	if failed:
		return
	if frames > MAX_FRAMES:
		print("FLOW TEST STUCK: turnState=%s currentPlayer=%s" % [poker.playersTurnState, poker.currentPlayer.name])
		get_tree().quit()
		return
	for playerName in poker.players:
		if poker.players[playerName].money < 0:
			print("FLOW TEST FAIL: negative money for %s: %d" % [playerName, poker.players[playerName].money])
			failed = true
			get_tree().quit()
			return
	if poker.gameActive:
		if poker.currentPlayer.name == "player1" and not poker.uIDisabled:
			var deficit: int = poker.table.highestBet - poker.table["player1"]
			if deficit > 0:
				poker.processPlayerTurn("player1", 3) # ACTION.CALLED
			else:
				poker.processPlayerTurn("player1", 1) # ACTION.PASSED
	elif wasGameActive:
		wasGameActive = false
		gamesPlayed += 1
		var sum := 0
		for playerName in poker.players:
			sum += poker.players[playerName].money
		print("FLOW TEST game %d finished: money sum=%d (expected %d), players left=%s" % [gamesPlayed, sum, totalMoney, poker.players.keys()])
		if sum != totalMoney:
			print("FLOW TEST FAIL: money not conserved")
			failed = true
			get_tree().quit()
			return
		if gamesPlayed >= MAX_GAMES:
			print("FLOW TEST DONE: %d games played, money conserved in all" % gamesPlayed)
			get_tree().quit()
			return
		if not poker.players.has("player1"):
			print("FLOW TEST DONE: player1 busted after %d games (game over flow reached)" % gamesPlayed)
			get_tree().quit()
			return
		poker.startGame()
		wasGameActive = true