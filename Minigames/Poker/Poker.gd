extends Node2D

var deck = []
var players = {}
var playerOrder = []
var table = {}

var currentPlayer
var playersTurnState = {
	"waiting": [],
	"passed": [],
	"raised": [],
	"called": [],
	"folded": []
}
var currentBidState = Poker.BID_STATES.PASS

var nextPlayerReady = false
var uIDisabled = true
var animatedObjects = []

func _ready() -> void:
	changeUIDisabledState()
	setPlayers()
	buildDeck()
	buildTable()
	$Popup.setPopupText("Santa Rose Poker", [
		"Santa Rose Poker is a game of cards. You bet money to win the entire bid. The highest hand wins.",
		"The game flow:",
		"1. Every player gets two cards, and three cards are dealt on the table",
		"2. Players decide if they want to bid money, pass, or fold",
		"3. If a player raises the bid, all players must raise the bid again, call the bid, or fold",
		"4. Once all players pass, call, or fold, a new card is dealt on the table",
		"5. Players can bid again",
		"6. One more card is dealt on the table",
		"7. Players can bid one last time",
		"8. After the bidding is done, cards are revealed, and the highest hand wins",
	])
	$Popup2.setPopupText("Hands", [
		"੥੥♡ Hearts: Red",
		"♢ Diamonds: Brown",
		"♤ Spades: Purple",
		"♧ Clubs: Green",
		"3. If a player raises the bid, all players must raise the bid again, call the bid, or fold",
		"4. Once all players pass, call, or fold, a new card is dealt on the table",
		"5. Players can bid again",
		"6. One more card is dealt on the table",
		"7. Players can bid one last time",
		"8. After the bidding is done, cards are revealed, and the highest hand wins",
	])
	$Popup2.setPopupImage("res://Assets/Cards/CardTwoofHearts.png")
	$Popup2.setPopupImage("res://Assets/Cards/CardTwoofSpades.png")

func _process(_delta: float) -> void:
	checkUIState()
	if nextPlayerReady and !currentPlayer.name == "player1":
		nextPlayerReady = false
		if playersTurnState.folded.has(currentPlayer.name):
			updateCurrentPlayer()
			animateObject()
			return
		calculatePlayerMove()

func checkUIState():
	if !uIDisabled:
		if int($Table/TableGrid/Player1UILeft/Player1UILeftContainer/Player1UILeftNumberContainer/Bid.text) == 0:
			$Table/TableGrid/Player1/Player1Container/VBoxContainer/Raise.disabled = true
		else:
			$Table/TableGrid/Player1/Player1Container/VBoxContainer/Raise.disabled = false
		if playersTurnState.raised.size() != 0 or playersTurnState.called.size() != 0:
			$Table/TableGrid/Player1/Player1Container/VBoxContainer2/Pass.disabled = true
		else:
			$Table/TableGrid/Player1/Player1Container/VBoxContainer2/Pass.disabled = false

func startGame() -> void:
	$Table/TableGrid/TableContainer/MenuUIMarginContainer.hide()
	$Table/TableGrid/TableContainer/TableDataContainer.show()
	buildDeck()
	buildTable()
	setBlinds()
	updateUI()
	dealCards(2, true)
	dealCards(3)
	animateObject()

func setPlayers(reset = false):
	if reset:
		for player in players.values:
			player.personality = Poker.PLAYER_PERSONALITIES[player.personality.name].duplicate(true)
		return
	currentPlayer = Poker.players["player1"]
	players = Poker.players
	for player in players:
		playerOrder.append(player)

func buildDeck() -> void:
	deck = Poker.CARDS.duplicate(true)
	deck.shuffle()

func buildTable() -> void:
	table = {
		"cards": [],
		"highestBet": 0
	}
	for player in players.values():
		table[player.name] = 0

func setBlinds():
	for player in players:
		var blind = 0
		if players[player].money < 5:
			blind += players[player].money
			players[player].money = 0
		else:
			blind += 5
			players[player].money -= 5
		table[player] += blind

func dealCards(cardAmount = 1, toPlayers = false) -> void:
	if toPlayers:
		for player in players.values():
			for i in range(1, cardAmount + 1):
				#Poker.PLAYER_CARD_PATHS[player.name]["card" + str(i)].cards.append(deck.pop_at(randi() % deck.size() - 1))
				var card = deck.pop_at(randi() % deck.size() - 1)
				createCard(
					card,
					"Card" + card.name.replace(" ", ""),
					Poker.PLAYER_CARD_PATHS[player.name]["card" + str(i)],
					get_node(Poker.PLAYER_CARD_PATHS[player.name]["card" + str(i)]).global_position,
					.15
				)
	else:
		for i in range(1, cardAmount + 1):
			var card = deck.pop_at(randi() % deck.size() - 1)
			table.cards.append(card)
			createCard(
				card,
				"Card" + card.name.replace(" ", ""),
				Poker.TABLE_CARD_PATHS["card" + str(table.cards.size())],
				get_node(Poker.TABLE_CARD_PATHS["card" + str(table.cards.size())]).global_position,
				.15
			)

func createCard(card, cardName, cardPath, cardEndPosition, cardDuration):
	var cardNode = load("res://Minigames/Poker/Card.tscn").instantiate()
	get_node(cardPath).add_child(cardNode)
	cardNode.init(card, cardName, cardPath, cardEndPosition, cardDuration)
	animatedObjects.append(cardNode)

func calculatePlayerMove():
	var cards = []
	for player in Poker.PLAYER_CARD_PATHS:
		if player == currentPlayer.name:
			for card in Poker.PLAYER_CARD_PATHS[player]:
				cards.append(get_node(Poker.PLAYER_CARD_PATHS[player][card]).get_child(0).card)
	cards.append_array(table.cards)
	var hand = calculateHand(cards)
	var playerAction = "passed"
	var playerActionAmount = 0
	match currentPlayer.personality.name:
		"Casual":
			if currentBidState == Poker.BID_STATES.CALL:
				if(
					(
						hand.hand == "Royal Straight Flush" or
						hand.hand == "Straight Flush" or
						hand.hand == "Four of a kind" or
						hand.hand == "Full house" or
						hand.hand == "Flush" or
						hand.hand == "Straight" or
						hand.hand == "Three of a kind" or
						hand.hand == "Two pairs" or
						hand.hand == "Two of a kind"
					) and
					currentPlayer.personality.raiseLimit > 0 and
					randi() % 4 == 0
				):
					playerAction = "raised"
					currentPlayer.personality.raiseLimit -= 1
					if currentPlayer.money < 2:
						playerActionAmount = currentPlayer.money
					else:
						playerActionAmount = players[currentPlayer.name].money * 0.05
						playerActionAmount += players[currentPlayer.name].money * (randi() % 10 / 100.0)
				elif(
					(
						hand.hand == "Royal Straight Flush" or
						hand.hand == "Straight Flush" or
						hand.hand == "Four of a kind" or
						hand.hand == "Full house" or
						hand.hand == "Flush" or
						hand.hand == "Straight" or
						hand.hand == "Three of a kind" or
						hand.hand == "Two pairs" or
						hand.hand == "Two of a kind"
					) and 
					randi() % 4 != 0
				):
					playerAction = "called"
				else:
					playerAction = "folded"
			elif(
				(
					hand.hand == "Royal Straight Flush" or
					hand.hand == "Straight Flush" or
					hand.hand == "Four of a kind" or
					hand.hand == "Full house" or
					hand.hand == "Flush" or
					hand.hand == "Straight" or
					hand.hand == "Three of a kind" or
					hand.hand == "Two pairs" or
					hand.hand == "Two of a kind"
				) and
				randi() % 5 != 0
			):
				playerAction = "raised"
				currentPlayer.personality.raiseLimit -= 1
				if currentPlayer.money < 2:
					playerActionAmount = currentPlayer.money
				else:
					playerActionAmount = players[currentPlayer.name].money * 0.075
					playerActionAmount += players[currentPlayer.name].money * (randi() % 15 / 100.0)
			else:
				if randi() % 20 == 0:
					playerAction = "folded"
		"Gambler":
			if currentBidState == Poker.BID_STATES.CALL:
				if(
					(
						hand.hand == "Royal Straight Flush" or
						hand.hand == "Straight Flush" or
						hand.hand == "Four of a kind" or
						hand.hand == "Full house" or
						hand.hand == "Flush" or
						hand.hand == "Straight" or
						hand.hand == "Three of a kind"
					) and
					currentPlayer.personality.raiseLimit > 0 and
					randi() % 8 != 0
				):
					playerAction = "raised"
					currentPlayer.personality.raiseLimit -= 1
					if currentPlayer.money < 2:
						playerActionAmount = currentPlayer.money
					else:
						playerActionAmount = players[currentPlayer.name].money * 0.1
						playerActionAmount += players[currentPlayer.name].money * (randi() % 20 / 100.0)
				elif(
					(
						hand.hand == "Royal Straight Flush" or
						hand.hand == "Straight Flush" or
						hand.hand == "Four of a kind" or
						hand.hand == "Full house" or
						hand.hand == "Flush" or
						hand.hand == "Straight" or
						hand.hand == "Three of a kind" or
						hand.hand == "Two pairs" or
						hand.hand == "Two of a kind"
					)
				):
					playerAction = "called"
				else:
					playerAction = "folded"
			elif(
				(
					hand.hand == "Royal Straight Flush" or
					hand.hand == "Straight Flush" or
					hand.hand == "Four of a kind" or
					hand.hand == "Full house"
				) and
				currentPlayer.personality.raiseLimit > 0
			):
				playerAction = "raised"
				currentPlayer.personality.raiseLimit -= 1
				playerActionAmount = players[currentPlayer.name].money
			elif(
				(
					hand.hand == "Flush" or
					hand.hand == "Straight"
				) and
				currentPlayer.personality.raiseLimit > 0
			):
				playerAction = "raised"
				currentPlayer.personality.raiseLimit -= 1
				if currentPlayer.money < 2:
					playerActionAmount = currentPlayer.money
				else:
					playerActionAmount = players[currentPlayer.name].money * 0.4
					playerActionAmount += players[currentPlayer.name].money * (randi() % 2 / 100.0)
			elif(
				(
					hand.hand == "Three of a kind" or
					hand.hand == "Two pairs" or
					hand.hand == "Two of a kind"
				) and
				currentPlayer.personality.raiseLimit > 0 and
				randi() % 5 != 0
			):
				playerAction = "raised"
				currentPlayer.personality.raiseLimit -= 1
				if currentPlayer.money < 2:
					playerActionAmount = currentPlayer.money
				else:
					playerActionAmount = players[currentPlayer.name].money * 0.1
					playerActionAmount += players[currentPlayer.name].money * (randi() % 40 / 100.0)
			else:
				if randi() % 50 == 0:
					playerAction = "folded"
		"Pinchpenny":
			if currentBidState == Poker.BID_STATES.CALL:
				if(
					(
						hand.hand == "Royal Straight Flush" or
						hand.hand == "Straight Flush" or
						hand.hand == "Four of a kind"
					) and
					currentPlayer.personality.raiseLimit > 0 and
					randi() % 4 != 0
				):
					playerAction = "raised"
					currentPlayer.personality.raiseLimit -= 1
					if currentPlayer.money < 2:
						playerActionAmount = currentPlayer.money
					else:
						playerActionAmount = players[currentPlayer.name].money * 0.025
						playerActionAmount += players[currentPlayer.name].money * (randi() % 5 / 100.0)
				elif(
					(
						hand.hand == "Royal Straight Flush" or
						hand.hand == "Straight Flush" or
						hand.hand == "Four of a kind" or
						hand.hand == "Full house" or
						hand.hand == "Flush"
					)
				):
					playerAction = "called"
				else:
					playerAction = "folded"
			elif(
				(
					hand.hand == "Royal Straight Flush" or
					hand.hand == "Straight Flush" or
					hand.hand == "Four of a kind" or
					hand.hand == "Full house" or
					hand.hand == "Flush" or
					hand.hand == "Straight" or
					hand.hand == "Three of a kind"
				) and 
				randi() % 2 == 0
			):
				playerAction = "raised"
				currentPlayer.personality.raiseLimit -= 1
				if currentPlayer.money < 2:
					playerActionAmount = currentPlayer.money
				else:
					playerActionAmount = players[currentPlayer.name].money * 0.025
					playerActionAmount += players[currentPlayer.name].money * (randi() % 5 / 100.0)
			else:
				if randi() % 15 == 0:
					playerAction = "folded"
		"Random":
			if currentBidState == Poker.BID_STATES.CALL:
				if(
					(
						hand.hand == "Royal Straight Flush" or
						hand.hand == "Straight Flush" or
						hand.hand == "Four of a kind" or
						hand.hand == "Full house" or
						hand.hand == "Flush" or
						hand.hand == "Straight" or
						hand.hand == "Three of a kind" or
						hand.hand == "Two pairs" or
						hand.hand == "Two of a kind"
					) and
					currentPlayer.personality.raiseLimit > 0 and
					randi() % 3 == 0
				):
					playerAction = "raised"
					currentPlayer.personality.raiseLimit -= 1
					if currentPlayer.money < 2:
						playerActionAmount = currentPlayer.money
					else:
						playerActionAmount = players[currentPlayer.name].money * 0.05
						playerActionAmount += players[currentPlayer.name].money * (randi() % 75 / 100.0)
				elif(
					(
						hand.hand == "Royal Straight Flush" or
						hand.hand == "Straight Flush" or
						hand.hand == "Four of a kind" or
						hand.hand == "Full house" or
						hand.hand == "Flush" or
						hand.hand == "Straight" or
						hand.hand == "Three of a kind" or
						hand.hand == "Two pairs" or
						hand.hand == "Two of a kind"
					) and 
					randi() % 2 == 0
				):
					playerAction = "called"
				else:
					playerAction = "folded"
			elif(
				(
					hand.hand == "Royal Straight Flush" or
					hand.hand == "Straight Flush" or
					hand.hand == "Four of a kind" or
					hand.hand == "Full house" or
					hand.hand == "Flush" or
					hand.hand == "Straight" or
					hand.hand == "Three of a kind" or
					hand.hand == "Two pairs" or
					hand.hand == "Two of a kind"
				) and
				currentPlayer.personality.raiseLimit > 0 and
				randi() % 2 == 0
			):
				playerAction = "raised"
				currentPlayer.personality.raiseLimit -= 1
				if currentPlayer.money < 2:
					playerActionAmount = currentPlayer.money
				else:
					playerActionAmount = players[currentPlayer.name].money * 0.075
					playerActionAmount += players[currentPlayer.name].money * (randi() % 75 / 100.0)
			else:
				if randi() % 30 == 0:
					playerAction = "folded"
	processPlayerTurn(currentPlayer.name, playerAction, playerActionAmount)

func processPlayerTurn(playerName, playerAction, playerActionAmount = 0) -> void:
	print("processPlayerTurn ",  playerName, " ", playerAction, " ", playerActionAmount)
	playPlayerTurn(playerName, playerAction, playerActionAmount)
	if !checkIfPlayersLeft():
		if playersTurnState.folded.size() == players.size() - 1:
			var winner = calculateWinner()
			dealWinnings(winner)
			updatePlayers()
			currentBidState = Poker.BID_STATES.PASS
			nextPlayerReady = false
			animatedObjects.clear()
			updateUI()
			resetUI()
			$Table/TableGrid/TableContainer/MenuUIMarginContainer.show()
			$Table/TableGrid/TableContainer/TableDataContainer.hide()
			return
		elif table.cards.size() < 5:
			dealCards(1)
			for player in players:
				if !playersTurnState.folded.has(player):
					updatePlayerTurnState(player, "waiting")
		else:
			var winner = calculateWinner()
			dealWinnings(winner)
			updatePlayers()
			currentBidState = Poker.BID_STATES.PASS
			nextPlayerReady = false
			animatedObjects.clear()
			updateUI()
			resetUI()
			$Table/TableGrid/TableContainer/MenuUIMarginContainer.show()
			$Table/TableGrid/TableContainer/TableDataContainer.hide()
			return
	animateObject()

func playPlayerTurn(playerName, playerAction, playerActionAmount) -> void:
	match playerAction:
		"raised":
			var raiseAmount = playerActionAmount
			if playerName == "player1":
				raiseAmount = int($Table/TableGrid/Player1UILeft/Player1UILeftContainer/Player1UILeftNumberContainer/Bid.text)
			table[playerName] += raiseAmount
			table.highestBet = table[playerName]
			players[playerName].money -= raiseAmount
			if currentBidState == Poker.BID_STATES.PASS:
				currentBidState = Poker.BID_STATES.CALL
		"called":
			table[playerName] += table.highestBet - table[playerName]
			players[playerName].money -= table.highestBet + table[playerName]
	if playerName != "player1":
		updateBidState(playerName, table[playerName], players[playerName].playerType)
		updateMoneyState(playerName, players[playerName].money, players[playerName].playerType)
	updateUI()
	updatePlayerTurnState(playerName, playerAction)
	updateCurrentPlayer()

func updatePlayerTurnState(playerName, playerAction = null) -> void:
	for turnState in playersTurnState:
		if playersTurnState[turnState].has(playerName):
			playersTurnState[turnState].erase(playerName)
			break
	if playerAction != null:
		playersTurnState[playerAction].append(playerName)

func updateCurrentPlayer() -> void:
	var currentPlayerPosition = playerOrder.find(currentPlayer.name)
	if currentPlayerPosition + 1 == players.size():
		currentPlayer = players[playerOrder[0]]
		return
	currentPlayer = players[playerOrder[currentPlayerPosition + 1]]

func checkIfPlayersLeft() -> bool:
	if(
		(
			playersTurnState.waiting.is_empty() and
			playersTurnState.passed.size() + playersTurnState.folded.size() == players.size()
		) or (
			playersTurnState.waiting.is_empty() and
			playersTurnState.passed.is_empty() and
			playersTurnState.raised.is_empty() and
			playersTurnState.called.size() + playersTurnState.folded.size() == players.size()
		) or (
			playersTurnState.folded.size() == players.size() - 1
		)
	):
		return false
	return true

func calculateWinner() -> String:
	if playersTurnState.folded.size() == players.size() - 1:
		for playerState in playersTurnState:
			if playersTurnState[playerState].size() != 0 and playerState != "folded":
				return playersTurnState[playerState][0]
	return calculateWinningHand()

func calculateWinningHand() -> String:
	var winner
	var currentWinningHand = {
		"player": null,
		"hand": null
	}
	for player in players.values():
		var cards = []
		for playerName in Poker.PLAYER_CARD_PATHS:
			if player.name == playerName:
				for card in Poker.PLAYER_CARD_PATHS[player.name]:
					cards.append(get_node(Poker.PLAYER_CARD_PATHS[player.name][card]).get_child(0).card)
				break
		cards.append_array(table.cards)
		var hand = calculateHand(cards)
		var winningHand = calculateHigherHand(hand, currentWinningHand)
		if !currentWinningHand.hand == winningHand:
			currentWinningHand = {
				"player": player.name,
				"hand": winningHand
			}
	winner = currentWinningHand
	return winner.player

func calculateHand(cards) -> Dictionary:
	for hand in Poker.HANDS:
		match hand:
			"Royal Straight Flush":
				for card in cards:
					if card.amount == 10:
						var royalStraightFlush = [card]
						for i in range(1, 5):
							for checkedCard in cards:
								if checkedCard.amount == card.amount + i and checkedCard.suit == card.suit:
									royalStraightFlush.append(checkedCard)
									break
						if royalStraightFlush.size() == 4:
							return {
								"hand": hand,
								"cards": royalStraightFlush
							}
			"Straight Flush":
				for card in cards:
					var straightFlush = [card]
					for i in range(1, 5):
						for checkedCard in cards:
							if checkedCard.amount == straightFlush.back().amount + i and checkedCard.suit == card.suit:
								straightFlush.append(checkedCard)
								break
					if straightFlush.size() == 4:
						return {
							"hand": hand,
							"cards": straightFlush
						}
			"Four of a kind":
				var fourOfAKind = []
				for card in cards:
					fourOfAKind.clear()
					for checkedCard in cards:
						if card.amount == checkedCard.amount and !fourOfAKind.has(checkedCard):
							fourOfAKind.append(checkedCard)
							break
					if fourOfAKind.size() == 4:
						return {
							"hand": hand,
							"cards": fourOfAKind
						}
			"Full house":
				var pair = null
				for card in cards:
					for checkedCard in cards:
						if card.amount == checkedCard.amount and card != checkedCard:
							pair = [card, checkedCard]
				var three = null
				for card in cards:
					for checkedCard in cards:
						if(
							card.amount == checkedCard.amount and
							card != checkedCard and
							pair[0] != card and
							pair[0] != checkedCard and
							pair[1] != card and
							pair[1] != checkedCard
						):
							three = [card, checkedCard]
				if pair and pair.size() == 2 and three and three.size() == 3:
					return {
						"hand": hand,
						"cards": {
							"pair": pair,
							"three": three
						}
					}
			"Flush":
				for card in cards:
					var flush = [card]
					for i in range(1, 5):
						for checkedCard in cards:
							if checkedCard.suit == card.suit and !flush.has(checkedCard):
								flush.append(checkedCard)
					if flush.size() == 4:
						return {
							"hand": hand,
							"cards": flush
						}
			"Straight":
				for card in cards:
					var straight = [card]
					for i in range(1, 6):
						for checkedCard in cards:
							if checkedCard.amount == straight.back().amount + i:
								straight.append(checkedCard)
								break
					if straight.size() == 5:
						return {
							"hand": hand,
							"cards": straight
						}
			"Three of a kind":
				var threeOfAKind = []
				for card in cards:
					threeOfAKind.clear()
					for checkedCard in cards:
						if card.amount == checkedCard.amount and !threeOfAKind.has(checkedCard):
							threeOfAKind.append(checkedCard)
							break
					if threeOfAKind.size() == 3:
						return {
							"hand": hand,
							"cards": threeOfAKind
						}
			"Two pairs":
				var firstPair = null
				for card in cards:
					for checkedCard in cards:
						if card.amount == checkedCard.amount and card != checkedCard:
							firstPair = [card, checkedCard]
				var secondPair = null
				for card in cards:
					for checkedCard in cards:
						if(
							card.amount == checkedCard.amount and
							card != checkedCard and
							firstPair[0] != card and
							firstPair[0] != checkedCard and
							firstPair[1] != card and
							firstPair[1] != checkedCard
						):
							secondPair = [card, checkedCard]
				if firstPair and firstPair.size() == 2 and secondPair and secondPair.size() == 2:
					return {
						"hand": hand,
						"cards": {
							"firstPair": firstPair,
							"secondPair": secondPair
						}
					}
			"Two of a kind":
				var twoOfAKind = []
				for card in cards:
					twoOfAKind.clear()
					for checkedCard in cards:
						if card.amount == checkedCard.amount and !twoOfAKind.has(checkedCard):
							twoOfAKind.append(checkedCard)
							break
					if twoOfAKind.size() == 2:
						return {
							"hand": hand,
							"cards": twoOfAKind
						}
			"High card":
				var highestCard = null
				for card in cards:
					if highestCard == null:
						highestCard = card
					if card.amount > highestCard.amount:
						highestCard = card
				return {
					"hand": hand,
					"cards": highestCard
				}
	push_error("No valid hand!")
	return {}

func calculateHigherHand(newHand, currentWinningHand):
	var newHandTypeRanking = Poker.HANDS.find(newHand.hand)
	var currentWinningHandTypeRanking = Poker.HANDS.find(currentWinningHand.hand)
	if newHandTypeRanking > currentWinningHandTypeRanking:
		return newHand
	elif currentWinningHandTypeRanking > newHandTypeRanking:
		return currentWinningHand
	match newHandTypeRanking:
		"Royal Straight Flush":
			if !(typeof(currentWinningHand) == TYPE_ARRAY):
				return [currentWinningHand, newHand]
			return currentWinningHand.append(newHand)
		"Full house":
			if (
				currentWinningHand.cards.has("pair") and
				currentWinningHand.cards.has("three") and
				newHand.cards.has("pair") and
				newHand.cards.has("three")
			):
				if (
					typeof(currentWinningHand) == TYPE_ARRAY and
					newHand.cards.pair[0].amount == currentWinningHand[0].cards.pair[0].amount and
					newHand.cards.pair[0].amount == currentWinningHand[0].cards.pair[0].amount and
					newHand.cards.three[0].amount == currentWinningHand[0].cards.three[0].amount and
					newHand.cards.three[0].amount == currentWinningHand[0].cards.three[0].amount
				):
					return currentWinningHand.merge(newHand)
				if (
					newHand.cards.pair[0].amount == currentWinningHand.cards.pair[0].amount and
					newHand.cards.pair[0].amount == currentWinningHand.cards.pair[0].amount and
					newHand.cards.three[0].amount == currentWinningHand.cards.three[0].amount and
					newHand.cards.three[0].amount == currentWinningHand.cards.three[0].amount
				):
					return [currentWinningHand, newHand]
				var newHandHighestThreeCard = newHand.three.cards[0].amount
				var currentHighestHandHighhestThreeCard = currentWinningHand.three.cards[0].amount
				var newHandHighestPairCard = newHand.pair.cards[0].amount
				var currentHighestHandHighhestPairCard = currentWinningHand.pair.cards[0].amount
				if (
					newHandHighestThreeCard > currentHighestHandHighhestThreeCard or
					(
						newHandHighestPairCard > currentHighestHandHighhestPairCard and
						newHandHighestThreeCard < currentHighestHandHighhestThreeCard
					)
				):
					return newHand
		"Straight Flush", "Flush", "Straight":
			var newHandHighestCard = null
			var currentWinningHandHighestCard = null
			var currentWinningHandCards
			if typeof(currentWinningHandHighestCard) == TYPE_ARRAY:
				currentWinningHandCards = currentWinningHand[0].cards[0]
			else:
				currentWinningHandCards = currentWinningHandCards.cards[0]
			for card in newHand.cards:
				if newHandHighestCard == null:
					newHandHighestCard = card
				if card.amount > newHandHighestCard:
					newHandHighestCard = card
			for card in currentWinningHandCards:
				if currentWinningHandHighestCard == null:
					currentWinningHandHighestCard = card
				if card.amount > currentWinningHandHighestCard:
					currentWinningHandHighestCard = card
			if (
				typeof(currentWinningHand) == TYPE_ARRAY and
				newHandHighestCard == currentWinningHandHighestCard
			):
				return currentWinningHand.merge(newHand)
			if newHandHighestCard == currentWinningHandHighestCard:
				return [currentWinningHand, newHand]
			if newHandHighestCard > currentWinningHandHighestCard:
				return newHand
		"Two pairs":
			if (
				currentWinningHand.cards.has("firstPair") and
				currentWinningHand.cards.has("secondPair") and
				newHand.cards.has("firstPair") and
				newHand.cards.has("secondPair")
			):
				if (
					typeof(currentWinningHand) == TYPE_ARRAY and
					newHand.cards.firstPair[0].amount == currentWinningHand[0].cards.firstPair[0].amount and
					newHand.cards.firstPair[0].amount == currentWinningHand[0].cards.firstPair[0].amount and
					newHand.cards.secondPair[0].amount == currentWinningHand[0].cards.secondPair[0].amount and
					newHand.cards.secondPair[0].amount == currentWinningHand[0].cards.secondPair[0].amount
				):
					return currentWinningHand.merge(newHand)
				if (
					newHand.cards.firstPair[0].amount == currentWinningHand.cards.firstPair[0].amount and
					newHand.cards.firstPair[0].amount == currentWinningHand.cards.firstPair[0].amount and
					newHand.cards.secondPair[0].amount == currentWinningHand.cards.secondPair[0].amount and
					newHand.cards.secondPair[0].amount == currentWinningHand.cards.secondPair[0].amount
				):
					return [currentWinningHand, newHand]
				var newHandHighestCard = newHand.firstPair.cards[0].amount
				var currentHighestHandHighhestCard = currentWinningHand.firstPair.cards[0].amount
				if newHand.secondPair.cards[0].amount > newHandHighestCard:
					newHandHighestCard = newHand.secondPair.cards[0].amount
				if currentWinningHand.secondPair.cards[0].amount > currentHighestHandHighhestCard:
					currentHighestHandHighhestCard = currentWinningHand.secondPair.cards[0].amount
				if newHandHighestCard > currentHighestHandHighhestCard:
					return newHand
		"Four of a kind", "Three of a kind", "Two of a kind":
			if (
				typeof(currentWinningHand) == TYPE_ARRAY and
				newHand.cards[0].amount == currentWinningHand[0].cards[0].amount
			):
				return currentWinningHand.merge(newHand)
			if newHand.cards[0].amount == currentWinningHand.cards[0].amount:
				return [currentWinningHand, newHand]
			if newHand.cards[0].amount > currentWinningHand.cards[0].amount:
				return newHand
		"High card":
			if (
				typeof(currentWinningHand) == TYPE_ARRAY and
				newHand.cards.amount == currentWinningHand[0].cards.amount
			):
				return currentWinningHand.merge(newHand)
			if newHand.cards.amount == currentWinningHand.cards.amount:
				return [currentWinningHand, newHand]
			if newHand.cards.amount > currentWinningHand.cards.amount:
				return newHand
	return currentWinningHand

func dealWinnings(winner):
	var winnings = 0
	for player in table:
		if "player" in player:
			winnings += table[player]
	if typeof(winner) == TYPE_ARRAY:
		pass
	players[winner].money += winnings

func updatePlayers() -> void:
	for player in players.keys():
		if players[player].money <= 0:
			playerOrder.erase(player)
			players.erase(player)
			table.erase(player)
			updatePlayerTurnState(player, null)
			get_node("Table/TableGrid/{player}/{player}Container".format({ "player": player[0].to_upper() + player.substr(1,-1) })).hide()
	for player in players:
		updatePlayerTurnState(player, "waiting")
	playerOrder.push_front(playerOrder.pop_back())


func animateObject():
	if animatedObjects.is_empty():
		nextPlayerReady = true
		changeUIDisabledState(false)
		return
	var tween = get_tree().create_tween()
	var object = animatedObjects.pop_front()
	tween.tween_property(get_node(object.path), "global_position", object.global_position, object.duration).from(get_node(Poker.DECK_PATH).global_position)
	tween.tween_callback(animateObject)
	await get_tree().physics_frame
	object.show()

func changeUIDisabledState(disabled = true):
	uIDisabled = disabled
	for node in get_tree().get_nodes_in_group("Game"):
		node.disabled = disabled
	checkUIState()

func updateUI():
	#$Table/TableGrid/Player1UILeft/Player1UILeftContainer/Player1UILeftNumberContainer/Bid.text = str(0)
	for player in players.values():
		updateBidState(player.name, table[player.name], player.playerType)
		updateMoneyState(player.name, players[player.name].money, player.playerType)

func resetUI():
	for paths in Poker.PLAYER_CARD_PATHS.values():
		for path in paths.values():
			for card in get_node(path).get_children():
				card.queue_free()
	for cards in $Table/TableGrid/TableContainer/TableDataContainer/TableCardsContainer.get_children():
		for card in cards.get_children():
			card.queue_free()

func updateMoneyState(player, money, playerType):
	var moneyNode
	if playerType == "player":
		moneyNode = get_node("Table/TableGrid/{player}UILeft/{player}UILeftContainer/{player}UILeftNumberContainer/Money".format({ "player": player[0].to_upper() + player.substr(1,-1) }))
	else:
		moneyNode = get_node("Table/TableGrid/{player}/{player}Container/{player}UITopContainer/{player}UITopNumberMarginContainer/{player}UITopNumberContainer/Money".format({ "player": player[0].to_upper() + player.substr(1,-1) }))
	moneyNode.text = str(money)

func updateBidState(player, bid, playerType):
	var bidNode
	if playerType == "player":
		bidNode = get_node("Table/TableGrid/{player}UILeft/{player}UILeftContainer/{player}UILeftNumberContainer/Bid".format({ "player": player[0].to_upper() + player.substr(1,-1) }))
	else:
		bidNode = get_node("Table/TableGrid/{player}/{player}Container/{player}UITopContainer/{player}UITopNumberMarginContainer/{player}UITopNumberContainer/Bid".format({ "player": player[0].to_upper() + player.substr(1,-1) }))
	bidNode.text = str(bid)


func _on_help_button_pressed() -> void:
	$Popup.show()

func _on_hands_button_pressed() -> void:
	$Popup2.show()

func _on_add_to_bid_pressed(addToBid: int) -> void:
	$Table/TableGrid/Player1UILeft/Player1UILeftContainer/Player1UILeftNumberContainer/Bid.text = str(int($Table/TableGrid/Player1UILeft/Player1UILeftContainer/Player1UILeftNumberContainer/Bid.text) + addToBid)
