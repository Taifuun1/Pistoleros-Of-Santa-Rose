extends BasePoker

const CARD_SCENE: PackedScene = preload("res://Minigames/Poker/Card.tscn")
const CARD_TWEEN_DURATION := 0.15
const BLIND_AMOUNT := 5
const SHOWDOWN_REVEAL_DELAY := 1.5

## Hand ranks, matching the order of Poker.HANDS. Lower is better.
const RANK := {
	"ROYAL_STRAIGHT_FLUSH": 0,
	"STRAIGHT_FLUSH": 1,
	"FOUR_OF_A_KIND": 2,
	"FULL_HOUSE": 3,
	"FLUSH": 4,
	"STRAIGHT": 5,
	"THREE_OF_A_KIND": 6,
	"TWO_PAIRS": 7,
	"TWO_OF_A_KIND": 8,
	"HIGH_CARD": 9,
}

## Hand sizes for this poker variant: flushes and straight flushes count
## four cards, a straight counts five.
const FLUSH_SIZE := 4
const STRAIGHT_FLUSH_SIZE := 4
const STRAIGHT_SIZE := 5

var deck: Array = []
var players: Dictionary = {}
var playerOrder: Array = []
var table: Dictionary = {}
var hands: Dictionary = {}

var currentPlayer: Dictionary = {}
var playersTurnState: Dictionary = {
	ACTION.WAITING: [],
	ACTION.PASSED: [],
	ACTION.RAISED: [],
	ACTION.CALLED: [],
	ACTION.FOLDED: [],
}
var currentBidState: int = Poker.BID_STATES.PASS

var nextPlayerReady := false
var uIDisabled := true
var animatedObjects: Array = []
var gameActive := false

@onready var menuUI: MarginContainer = $Table/TableGrid/TableContainer/MenuUIMarginContainer
@onready var tableData: VBoxContainer = $Table/TableGrid/TableContainer/TableDataContainer
@onready var tableCardsContainer: HBoxContainer = $Table/TableGrid/TableContainer/TableDataContainer/TableCardsContainer
@onready var raiseLabel: Label = $Table/TableGrid/Player1UILeft/Player1UILeftContainer/Player1UILeftNumberContainer/Raise
@onready var raiseButton: Button = $Table/TableGrid/Player1/Player1Container/VBoxContainer/Raise
@onready var passButton: Button = $Table/TableGrid/Player1/Player1Container/VBoxContainer2/Pass
@onready var callButton: Button = $Table/TableGrid/Player1/Player1Container/VBoxContainer2/Call
@onready var dealButton: Button = $Table/TableGrid/TableContainer/MenuUIMarginContainer/MenuUIContainer/Deal
@onready var sfxPlayer: AudioStreamPlayer = $Audio/SFXPlayer
@onready var deckNode: TextureRect = $Table/TableGrid/DeckContainer/DeckPositionContainer/Deck

func _ready() -> void:
	setPlayers()
	dealButton.disabled = players["player1"].money <= 0
	changeUIDisabledState(true)

func _process(_delta: float) -> void:
	if not gameActive or not nextPlayerReady:
		return
	if currentPlayer.is_empty() or currentPlayer.name == "player1":
		return
	nextPlayerReady = false
	if playersTurnState[ACTION.FOLDED].has(currentPlayer.name):
		updateCurrentPlayer()
		animateObject()
		return
	calculatePlayerMove()

func setPlayers() -> void:
	if not Poker.players.has("player1"):
		# player1 busted out earlier this session and was removed from the
		# global player list; restore the entry so the table can load.
		Poker.players["player1"] = { "name": "player1", "money": 0, "playerType": "player" }
	players = Poker.players
	players["player1"].money = PokerMoney.money
	playerOrder.clear()
	for playerName in players:
		playerOrder.append(playerName)
	currentPlayer = players[playerOrder[0]]

func resetAIPersonalities() -> void:
	# Each AI gets a fresh copy of its personality every game so raise
	# limits reset and the shared templates are never mutated.
	for player in players.values():
		if player.playerType == "ai":
			player.personality = Poker.PLAYER_PERSONALITIES[player.personality.name].duplicate(true)

func resetTurnState() -> void:
	for turnState in playersTurnState:
		playersTurnState[turnState].clear()
	for playerName in players:
		playersTurnState[ACTION.WAITING].append(playerName)

func startGame() -> void:
	gameActive = true
	menuUI.hide()
	tableData.show()
	resetAIPersonalities()
	resetTurnState()
	currentBidState = Poker.BID_STATES.PASS
	currentPlayer = players[playerOrder[0]]
	buildDeck()
	buildTable()
	setBlinds()
	updateUI()
	# Wait a frame so the freshly shown containers finish layout before
	# card slot positions are read for the deal animations.
	await get_tree().process_frame
	dealCards(2, true)
	dealCards(3)
	animateObject()

func leaveGame() -> void:
	if players.has("player1"):
		PokerMoney.money = players["player1"].money
	get_tree().change_scene_to_file("res://Overworld/Overworld.tscn")

func buildDeck() -> void:
	deck = Poker.CARDS.duplicate(true)
	deck.shuffle()

func buildTable() -> void:
	table = {
		"cards": [],
		"highestBet": 0,
	}
	hands.clear()
	for playerName in players:
		table[playerName] = 0
		hands[playerName] = []

func setBlinds() -> void:
	for playerName in players:
		var blind: int = mini(players[playerName].money, BLIND_AMOUNT)
		players[playerName].money -= blind
		table[playerName] += blind

func dealCards(cardAmount: int = 1, toPlayers: bool = false) -> void:
	sfxPlayer["parameters/switch_to_clip"] = "Deal"
	if toPlayers:
		for playerName in players:
			for i in range(1, cardAmount + 1):
				var cardData: Dictionary = deck.pop_back()
				hands[playerName].append(cardData)
				var slotPath: String = Poker.PLAYER_CARD_PATHS[playerName]["card" + str(i)]
				createCard(cardData, slotPath, players[playerName].playerType != "player", get_node(slotPath).global_position)
	else:
		for i in range(1, cardAmount + 1):
			var cardData: Dictionary = deck.pop_back()
			table.cards.append(cardData)
			var slotPath: String = Poker.TABLE_CARD_PATHS["card" + str(table.cards.size())]
			createCard(cardData, slotPath, false, get_node(slotPath).global_position)

func createCard(cardData: Dictionary, slotPath: String, faceDown: bool, endPosition: Vector2) -> void:
	var cardNode = CARD_SCENE.instantiate()
	get_node(slotPath).add_child(cardNode)
	cardNode.init(cardData, faceDown, endPosition, CARD_TWEEN_DURATION)
	animatedObjects.append(cardNode)

func calculatePlayerMove() -> void:
	var hand: Dictionary = calculateHand(hands[currentPlayer.name] + table.cards)
	var playerAction: int = ACTION.PASSED
	var playerActionAmount := 0
	var canRaise: bool = currentPlayer.personality.raiseLimit > 0 and currentPlayer.money >= 1
	match currentPlayer.personality.name:
		"Casual":
			if currentBidState == Poker.BID_STATES.CALL:
				if hand.rank <= RANK.TWO_OF_A_KIND and canRaise and randi() % 4 == 0:
					playerAction = ACTION.RAISED
					playerActionAmount = _raiseAmount(0.05, 10)
				elif hand.rank <= RANK.TWO_OF_A_KIND and randi() % 4 != 0:
					playerAction = ACTION.CALLED
				else:
					playerAction = ACTION.FOLDED
			elif hand.rank <= RANK.TWO_OF_A_KIND and canRaise and randi() % 5 != 0:
				playerAction = ACTION.RAISED
				playerActionAmount = _raiseAmount(0.075, 15)
			elif randi() % 20 == 0:
				playerAction = ACTION.FOLDED
		"Gambler":
			if currentBidState == Poker.BID_STATES.CALL:
				if randi() % 25 == 0:
					playerAction = ACTION.CALLED
				elif hand.rank <= RANK.THREE_OF_A_KIND and canRaise and randi() % 8 != 0:
					playerAction = ACTION.RAISED
					playerActionAmount = _raiseAmount(0.1, 20)
				elif hand.rank <= RANK.TWO_OF_A_KIND:
					playerAction = ACTION.CALLED
				else:
					playerAction = ACTION.FOLDED
			elif hand.rank <= RANK.FULL_HOUSE and canRaise:
				playerAction = ACTION.RAISED
				playerActionAmount = currentPlayer.money
			elif hand.rank <= RANK.STRAIGHT and canRaise:
				playerAction = ACTION.RAISED
				playerActionAmount = _raiseAmount(0.4, 2)
			elif hand.rank <= RANK.TWO_OF_A_KIND and canRaise and randi() % 5 != 0:
				playerAction = ACTION.RAISED
				playerActionAmount = _raiseAmount(0.1, 40)
			elif randi() % 50 == 0:
				playerAction = ACTION.FOLDED
		"Pinchpenny":
			if currentBidState == Poker.BID_STATES.CALL:
				if hand.rank <= RANK.FOUR_OF_A_KIND and canRaise and randi() % 4 != 0:
					playerAction = ACTION.RAISED
					playerActionAmount = _raiseAmount(0.025, 5)
				elif hand.rank <= RANK.FLUSH:
					playerAction = ACTION.CALLED
				else:
					playerAction = ACTION.FOLDED
			elif hand.rank <= RANK.THREE_OF_A_KIND and canRaise and randi() % 2 == 0:
				playerAction = ACTION.RAISED
				playerActionAmount = _raiseAmount(0.025, 5)
			elif randi() % 15 == 0:
				playerAction = ACTION.FOLDED
		"Random":
			if currentBidState == Poker.BID_STATES.CALL:
				if hand.rank <= RANK.TWO_OF_A_KIND and canRaise and randi() % 3 == 0:
					playerAction = ACTION.RAISED
					playerActionAmount = _raiseAmount(0.05, 75)
				elif hand.rank <= RANK.TWO_OF_A_KIND and randi() % 2 == 0:
					playerAction = ACTION.CALLED
				else:
					playerAction = ACTION.FOLDED
			elif hand.rank <= RANK.TWO_OF_A_KIND and canRaise and randi() % 2 == 0:
				playerAction = ACTION.RAISED
				playerActionAmount = _raiseAmount(0.075, 75)
			elif randi() % 30 == 0:
				playerAction = ACTION.FOLDED
	if playerAction == ACTION.RAISED:
		currentPlayer.personality.raiseLimit -= 1
	processPlayerTurn(currentPlayer.name, playerAction, playerActionAmount)

## Bet sizing shared by all personalities: base percentage of the player's
## money plus a random extra percentage, at least 1, everything when broke.
func _raiseAmount(baseFraction: float, randomPercent: int) -> int:
	if currentPlayer.money <= 2:
		return currentPlayer.money
	var amount: float = currentPlayer.money * baseFraction
	amount += currentPlayer.money * (randi() % randomPercent / 100.0)
	return maxi(int(amount), 1)

func processPlayerTurn(playerName: String, playerAction: int, playerActionAmount: int = 0) -> void:
	if not gameActive or playerName != currentPlayer.name:
		return
	if playerAction == ACTION.PASSED and table.highestBet > table[playerName]:
		# Illegal: facing a bet, the player must call, raise, or fold.
		return
	if playerName == "player1":
		changeUIDisabledState(true)
	playPlayerTurn(playerName, playerAction, playerActionAmount)
	if not shouldRoundContinue():
		endBettingRound()
		return
	animateObject()

func playPlayerTurn(playerName: String, playerAction: int, playerActionAmount: int) -> void:
	var effectiveAction := playerAction
	if effectiveAction == ACTION.RAISED:
		var raiseAmount := playerActionAmount
		if playerName == "player1":
			raiseAmount = int(raiseLabel.text)
		raiseAmount = mini(raiseAmount, players[playerName].money)
		if table[playerName] + raiseAmount <= table.highestBet:
			# Not enough to raise above the current highest bet (for example
			# an all-in below it): treat the action as a call instead.
			effectiveAction = ACTION.CALLED
		else:
			table[playerName] += raiseAmount
			table.highestBet = maxi(table.highestBet, table[playerName])
			players[playerName].money -= raiseAmount
			currentBidState = Poker.BID_STATES.CALL
			# A raise reopens the betting: everyone still in the hand must act again.
			for otherPlayerName in players:
				if otherPlayerName != playerName and not playersTurnState[ACTION.FOLDED].has(otherPlayerName):
					setPlayerTurnState(otherPlayerName, ACTION.WAITING)
			sfxPlayer["parameters/switch_to_clip"] = "Raise"
			sfxPlayer.play()
	if effectiveAction == ACTION.CALLED and table.highestBet <= table[playerName]:
		# Nothing to call: the action is equivalent to a pass.
		effectiveAction = ACTION.PASSED
	if effectiveAction == ACTION.CALLED:
		var callAmount: int = clampi(table.highestBet - table[playerName], 0, players[playerName].money)
		table[playerName] += callAmount
		players[playerName].money -= callAmount
	if playerName != "player1":
		updateBidState(playerName, table[playerName], players[playerName].playerType)
		updateMoneyState(playerName, players[playerName].money, players[playerName].playerType)
	updateUI()
	setPlayerTurnState(playerName, effectiveAction)
	updateCurrentPlayer()

func setPlayerTurnState(playerName: String, turnState: int) -> void:
	removePlayerFromTurnState(playerName)
	playersTurnState[turnState].append(playerName)

func removePlayerFromTurnState(playerName: String) -> void:
	for turnState in playersTurnState:
		playersTurnState[turnState].erase(playerName)

func updateCurrentPlayer() -> void:
	if playerOrder.is_empty():
		return
	var playerPosition := playerOrder.find(currentPlayer.name)
	currentPlayer = players[playerOrder[(playerPosition + 1) % playerOrder.size()]]

func shouldRoundContinue() -> bool:
	var waiting: Array = playersTurnState[ACTION.WAITING]
	var passed: Array = playersTurnState[ACTION.PASSED]
	var raised: Array = playersTurnState[ACTION.RAISED]
	var called: Array = playersTurnState[ACTION.CALLED]
	var folded: Array = playersTurnState[ACTION.FOLDED]
	if folded.size() == players.size() - 1:
		return false
	if waiting.is_empty() and passed.size() + folded.size() == players.size():
		return false
	if waiting.is_empty() and passed.is_empty() and called.size() + raised.size() + folded.size() == players.size():
		return false
	return true

func endBettingRound() -> void:
	if playersTurnState[ACTION.FOLDED].size() == players.size() - 1:
		endRound()
		return
	if table.cards.size() < 5:
		dealCards(1)
		for playerName in players:
			if not playersTurnState[ACTION.FOLDED].has(playerName):
				setPlayerTurnState(playerName, ACTION.WAITING)
		currentBidState = Poker.BID_STATES.PASS
		animateObject()
		return
	endRound()

func endRound() -> void:
	nextPlayerReady = false
	animatedObjects.clear()
	revealCards()
	var winners: Array = calculateWinner()
	dealWinnings(winners)
	updatePlayers()
	currentBidState = Poker.BID_STATES.PASS
	# Keep the game marked active during the reveal so nothing (the Deal
	# button included) can start the next game before the cleanup below.
	await get_tree().create_timer(SHOWDOWN_REVEAL_DELAY).timeout
	gameActive = false
	resetUI()
	if not players.has("player1"):
		gameOver()
		return
	updateUI()
	menuUI.show()
	tableData.hide()

func gameOver() -> void:
	PokerMoney.money = 0
	dealButton.disabled = true
	menuUI.show()
	tableData.hide()

func calculateWinner() -> Array:
	if playersTurnState[ACTION.FOLDED].size() == players.size() - 1:
		for turnState in playersTurnState:
			if turnState == ACTION.FOLDED:
				continue
			if not playersTurnState[turnState].is_empty():
				return [playersTurnState[turnState][0]]
	return calculateWinningHands()

func calculateWinningHands() -> Array:
	var winners: Array = []
	var bestScore: Array = []
	for playerName in players:
		if playersTurnState[ACTION.FOLDED].has(playerName):
			continue
		var hand: Dictionary = calculateHand(hands[playerName] + table.cards)
		var score: Array = [hand.rank]
		score.append_array(hand.tiebreak)
		if winners.is_empty() or compareHands(score, bestScore) < 0:
			bestScore = score
			winners = [playerName]
		elif compareHands(score, bestScore) == 0:
			winners.append(playerName)
	return winners

## Compares two hand scores of [rank, tiebreak1, tiebreak2, ...].
## Returns a negative number when a wins, positive when b wins, 0 on a tie.
func compareHands(a: Array, b: Array) -> int:
	if a[0] != b[0]:
		return a[0] - b[0]
	for i in range(1, mini(a.size(), b.size())):
		if a[i] != b[i]:
			return b[i] - a[i]
	return 0

func calculateHand(cards: Array) -> Dictionary:
	var amountCounts := {}
	var suitedAmounts := {}
	for cardData in cards:
		amountCounts[cardData.amount] = amountCounts.get(cardData.amount, 0) + 1
		if not suitedAmounts.has(cardData.suit):
			suitedAmounts[cardData.suit] = []
		suitedAmounts[cardData.suit].append(cardData.amount)

	var amountsDesc: Array = amountCounts.keys()
	amountsDesc.sort()
	amountsDesc.reverse()
	for suit in suitedAmounts:
		suitedAmounts[suit].sort()
		suitedAmounts[suit].reverse()

	# Amounts grouped by how many times they appear, each group high to low.
	var amountsByCount := {}
	for amount in amountsDesc:
		var count: int = amountCounts[amount]
		if not amountsByCount.has(count):
			amountsByCount[count] = []
		amountsByCount[count].append(amount)

	var flushSuit := -1
	for suit in suitedAmounts:
		if suitedAmounts[suit].size() >= FLUSH_SIZE:
			flushSuit = suit
			break

	if flushSuit != -1:
		var suited: Array = suitedAmounts[flushSuit]
		if suited.has(10) and suited.has(11) and suited.has(12) and suited.has(13):
			return _makeHand(RANK.ROYAL_STRAIGHT_FLUSH, [13])
		var straightFlushHigh := findStraightHigh(suited, STRAIGHT_FLUSH_SIZE)
		if straightFlushHigh != -1:
			return _makeHand(RANK.STRAIGHT_FLUSH, [straightFlushHigh])
	if amountsByCount.has(4):
		var fourAmount: int = amountsByCount[4][0]
		return _makeHand(RANK.FOUR_OF_A_KIND, [fourAmount] + _highestExcept(amountsDesc, [fourAmount], 1))
	if amountsByCount.has(3):
		var threeAmount: int = amountsByCount[3][0]
		var pairAmount := -1
		if amountsByCount[3].size() > 1:
			pairAmount = amountsByCount[3][1]
		if amountsByCount.has(2):
			pairAmount = maxi(pairAmount, amountsByCount[2][0])
		if pairAmount != -1:
			return _makeHand(RANK.FULL_HOUSE, [threeAmount, pairAmount])
	if flushSuit != -1:
		return _makeHand(RANK.FLUSH, suitedAmounts[flushSuit].slice(0, FLUSH_SIZE))
	var straightHigh := findStraightHigh(amountsDesc, STRAIGHT_SIZE)
	if straightHigh != -1:
		return _makeHand(RANK.STRAIGHT, [straightHigh])
	if amountsByCount.has(3):
		var threeAmount: int = amountsByCount[3][0]
		return _makeHand(RANK.THREE_OF_A_KIND, [threeAmount] + _highestExcept(amountsDesc, [threeAmount], 2))
	if amountsByCount.has(2) and amountsByCount[2].size() > 1:
		var highPair: int = amountsByCount[2][0]
		var lowPair: int = amountsByCount[2][1]
		return _makeHand(RANK.TWO_PAIRS, [highPair, lowPair] + _highestExcept(amountsDesc, [highPair, lowPair], 1))
	if amountsByCount.has(2):
		var pairAmount: int = amountsByCount[2][0]
		return _makeHand(RANK.TWO_OF_A_KIND, [pairAmount] + _highestExcept(amountsDesc, [pairAmount], 3))
	return _makeHand(RANK.HIGH_CARD, amountsDesc.slice(0, 5))

func _makeHand(rank: int, tiebreak: Array) -> Dictionary:
	return {
		"hand": Poker.HANDS[rank],
		"rank": rank,
		"tiebreak": tiebreak,
	}

## Returns the highest card amount completing a run of runLength consecutive
## amounts, or -1 when there is no run. The ace counts as both high and low.
func findStraightHigh(amounts: Array, runLength: int) -> int:
	var uniqueAmounts := amounts.duplicate()
	uniqueAmounts.sort()
	if uniqueAmounts.has(14):
		uniqueAmounts.push_front(1)
	var best := -1
	var run := 1
	for i in range(1, uniqueAmounts.size()):
		if uniqueAmounts[i] == uniqueAmounts[i - 1] + 1:
			run += 1
			if run >= runLength:
				best = uniqueAmounts[i]
		elif uniqueAmounts[i] != uniqueAmounts[i - 1]:
			run = 1
	return best

func _highestExcept(amountsDesc: Array, excluded: Array, count: int) -> Array:
	var result := []
	for amount in amountsDesc:
		if excluded.has(amount):
			continue
		result.append(amount)
		if result.size() == count:
			break
	return result

func dealWinnings(winners: Array) -> void:
	var winnings := 0
	for playerName in players:
		winnings += table[playerName]
	var share: int = floori(float(winnings) / winners.size())
	var remainder: int = winnings - share * winners.size()
	for i in range(winners.size()):
		players[winners[i]].money += share + (1 if i < remainder else 0)

func updatePlayers() -> void:
	for playerName in players.keys():
		if players[playerName].money <= 0:
			playerOrder.erase(playerName)
			players.erase(playerName)
			table.erase(playerName)
			hands.erase(playerName)
			removePlayerFromTurnState(playerName)
			get_node("Table/TableGrid/{player}/{player}Container".format({ "player": _playerNodeName(playerName) })).hide()
	if players.is_empty():
		return
	for playerName in players:
		setPlayerTurnState(playerName, ACTION.WAITING)
	playerOrder.push_front(playerOrder.pop_back())
	if currentPlayer.is_empty() or not players.has(currentPlayer.name):
		currentPlayer = players[playerOrder[0]]

func revealCards() -> void:
	for playerName in players:
		if players[playerName].playerType == "player":
			continue
		if playersTurnState[ACTION.FOLDED].has(playerName):
			continue
		for slotPath in Poker.PLAYER_CARD_PATHS[playerName].values():
			for cardNode in get_node(slotPath).get_children():
				cardNode.reveal()

func animateObject() -> void:
	if animatedObjects.is_empty():
		onAnimationsFinished()
		return
	var cardNode = animatedObjects.pop_front()
	var tween := get_tree().create_tween()
	tween.tween_property(cardNode, "global_position", cardNode.endPosition, cardNode.duration).from(deckNode.global_position)
	tween.tween_callback(animateObject)
	await get_tree().process_frame
	cardNode.show()
	sfxPlayer.play()

func onAnimationsFinished() -> void:
	if not gameActive:
		return
	if currentPlayer.name == "player1":
		changeUIDisabledState(false)
	else:
		nextPlayerReady = true

func changeUIDisabledState(disabled: bool = true) -> void:
	uIDisabled = disabled
	for node in get_tree().get_nodes_in_group("Game"):
		node.disabled = disabled
	if not disabled:
		updateActionButtons()

func updateActionButtons() -> void:
	if uIDisabled or not players.has("player1"):
		return
	var callDeficit: int = table.highestBet - table.get("player1", 0)
	callButton.disabled = callDeficit <= 0
	passButton.disabled = callDeficit > 0
	raiseButton.disabled = int(raiseLabel.text) == 0 or players["player1"].money <= callDeficit

func updateUI() -> void:
	raiseLabel.text = str(0)
	for player in players.values():
		updateBidState(player.name, table.get(player.name, 0), player.playerType)
		updateMoneyState(player.name, player.money, player.playerType)
	updateActionButtons()

func resetUI() -> void:
	for paths in Poker.PLAYER_CARD_PATHS.values():
		for slotPath in paths.values():
			for cardNode in get_node(slotPath).get_children():
				cardNode.queue_free()
	for slotNode in tableCardsContainer.get_children():
		for cardNode in slotNode.get_children():
			cardNode.queue_free()

## "player1" -> "Player1", matching the UI node names. (String.capitalize()
## would insert a space before the digit.)
func _playerNodeName(playerName: String) -> String:
	return playerName[0].to_upper() + playerName.substr(1)

func updateMoneyState(playerName: String, money: int, playerType: String) -> void:
	var moneyNode: Label
	if playerType == "player":
		moneyNode = get_node("Table/TableGrid/{player}UILeft/{player}UILeftContainer/{player}UILeftNumberContainer/Money".format({ "player": _playerNodeName(playerName) }))
	else:
		moneyNode = get_node("Table/TableGrid/{player}/{player}Container/{player}UITopContainer/{player}UITopNumberMarginContainer/{player}UITopNumberContainer/Money".format({ "player": _playerNodeName(playerName) }))
	moneyNode.text = str(money)

func updateBidState(playerName: String, bid: int, playerType: String) -> void:
	var bidNode: Label
	if playerType == "player":
		bidNode = get_node("Table/TableGrid/{player}UILeft/{player}UILeftContainer/{player}UILeftNumberContainer/Bid".format({ "player": _playerNodeName(playerName) }))
	else:
		bidNode = get_node("Table/TableGrid/{player}/{player}Container/{player}UITopContainer/{player}UITopNumberMarginContainer/{player}UITopNumberContainer/Bid".format({ "player": _playerNodeName(playerName) }))
	bidNode.text = str(bid)

func _on_help_button_pressed() -> void:
	$Popups/Rules.show()

func _on_hands_button_pressed() -> void:
	$Popups/Cards.show()

func _on_add_to_bid_pressed(addToBid: int) -> void:
	if not players.has("player1"):
		return
	raiseLabel.text = str(mini(int(raiseLabel.text) + addToBid, players["player1"].money))
	updateActionButtons()