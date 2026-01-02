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

func _init() -> void:
	setPlayers()
	buildDeck()
	currentBidState = Poker.BID_STATES.PASS

func startGame() -> void:
	buildDeck()
	dealCards(2, true)
	dealCards(3)

func setPlayers(reset = false):
	if reset:
		for player in players:
			players[player].personality = Poker.PLAYER_PERSONALITIES[player.personality.name]
		return
	players = Poker.players
	for player in players:
		playerOrder.append(player)

func buildDeck() -> void:
	deck = Poker.CARDS.duplicate(true)
	deck.shuffle()

func dealCards(cardAmount = 1, toPlayers = false) -> void:
	if toPlayers:
		for playerName in players:
			for i in range(cardAmount):
				players[playerName].cards.append(deck.pop_at(randi() % deck.size() - 1))
	else:
		for i in range(cardAmount):
			table.cards.append(deck.pop_at(randi() % deck.size() - 1))

func calculatePlayerMove():
	var playerPersonality = Poker.PLAYER_PERSONALITIES[currentPlayer.personality]
	var cards = players[currentPlayer.name].cards
	cards.merge(table.cards)
	var hand = calculateHand(cards)
	var playerAction = "pass"
	var playerActionAmount = 0
	match playerPersonality:
		"Casual":
			if currentBidState == Poker.BID_STATES.CALL:
				if randi() % 10 == 0:
					playerAction = "fold"
				if(
					(
						hand == "Royal Straight Flush" or
						hand == "Straight Flush" or
						hand == "Four of a kind" or
						hand == "Full house" or
						hand == "Flush" or
						hand == "Straight" or
						hand == "Three of a kind" or
						hand == "Two pairs" or
						hand == "Two of a kind"
					) and 
					randi() % 4 == 0
				):
					playerAction = "raise"
					if currentPlayer.money <= 10:
						playerActionAmount += 10
					else:
						playerActionAmount = players[currentPlayer.name].money * 0.05
						playerActionAmount += players[currentPlayer.name].money * (randi() % 10 / 100)
				if(
					(
						hand == "Royal Straight Flush" or
						hand == "Straight Flush" or
						hand == "Four of a kind" or
						hand == "Full house" or
						hand == "Flush" or
						hand == "Straight" or
						hand == "Three of a kind" or
						hand == "Two pairs" or
						hand == "Two of a kind"
					) and 
					randi() % 3 == 0
				):
					playerAction = "call"
			if(
				(
					hand == "Royal Straight Flush" or
					hand == "Straight Flush" or
					hand == "Four of a kind" or
					hand == "Full house" or
					hand == "Flush" or
					hand == "Straight" or
					hand == "Three of a kind" or
					hand == "Two pairs" or
					hand == "Two of a kind"
				) and
				randi() % 5 != 0
			):
				playerAction = "raise"
				if currentPlayer.money <= 10:
					playerActionAmount += 10
				else:
					playerActionAmount = players[currentPlayer.name].money * 0.075
					playerActionAmount += players[currentPlayer.name].money * (randi() % 15 / 100)
		"Gambler":
			if currentBidState == Poker.BID_STATES.CALL:
				if randi() % 20 == 0:
					playerAction = "fold"
				if(
					(
						hand == "Royal Straight Flush" or
						hand == "Straight Flush" or
						hand == "Four of a kind" or
						hand == "Full house" or
						hand == "Flush" or
						hand == "Straight" or
						hand == "Three of a kind"
					) and 
					randi() % 4 != 0
				):
					playerAction = "raise"
					if currentPlayer.money <= 10:
						playerActionAmount += 10
					else:
						playerActionAmount = players[currentPlayer.name].money * 0.1
						playerActionAmount += players[currentPlayer.name].money * (randi() % 20 / 100)
				if(
					(
						hand == "Royal Straight Flush" or
						hand == "Straight Flush" or
						hand == "Four of a kind" or
						hand == "Full house" or
						hand == "Flush" or
						hand == "Straight" or
						hand == "Three of a kind" or
						hand == "Two pairs" or
						hand == "Two of a kind"
					)
				):
					playerAction = "call"
			if(
				(
					hand == "Royal Straight Flush" or
					hand == "Straight Flush" or
					hand == "Four of a kind" or
					hand == "Full house"
				)
			):
				playerAction = "raise"
				playerActionAmount = players[currentPlayer.name].money
			if(
				(
					hand == "Flush" or
					hand == "Straight"
				)
			):
				playerAction = "raise"
				if currentPlayer.money <= 10:
					playerActionAmount += 10
				else:
					playerActionAmount = players[currentPlayer.name].money * 0.4
					playerActionAmount += players[currentPlayer.name].money * (randi() % 2 / 100)
			if(
				(
					hand == "Three of a kind" or
					hand == "Two pairs" or
					hand == "Two of a kind"
				) and
				randi() % 2 != 0
			):
				playerAction = "raise"
				if currentPlayer.money <= 10:
					playerActionAmount += 10
				else:
					playerActionAmount = players[currentPlayer.name].money * 0.1
					playerActionAmount += players[currentPlayer.name].money * (randi() % 40 / 100)
		"Pinchpenny":
			if currentBidState == Poker.BID_STATES.CALL:
				if randi() % 2 == 0:
					playerAction = "fold"
				if(
					(
						hand == "Royal Straight Flush" or
						hand == "Straight Flush" or
						hand == "Four of a kind"
					) and 
					randi() % 4 != 0
				):
					playerAction = "raise"
					if currentPlayer.money <= 10:
						playerActionAmount += 10
					else:
						playerActionAmount = players[currentPlayer.name].money * 0.025
						playerActionAmount += players[currentPlayer.name].money * (randi() % 5 / 100)
				if(
					(
						hand == "Full house" or
						hand == "Flush"
					)
				):
					playerAction = "call"
			if(
				(
					hand == "Royal Straight Flush" or
					hand == "Straight Flush" or
					hand == "Four of a kind"
				) and 
				randi() % 4 != 0
			):
				playerAction = "raise"
				if currentPlayer.money <= 10:
					playerActionAmount += 10
				else:
					playerActionAmount = players[currentPlayer.name].money * 0.025
					playerActionAmount += players[currentPlayer.name].money * (randi() % 5 / 100)
			if(
				(
					hand == "Full house" or
					hand == "Flush" or
					hand == "Straight" or
					hand == "Three of a kind" or
					hand == "Two pairs" or
					hand == "Two of a kind"
				) and
				randi() % 2 != 0
			):
				playerAction = "call"
		"Random":
			if currentBidState == Poker.BID_STATES.CALL:
				if randi() % 15 == 0:
					playerAction = "fold"
				elif(
					(
						hand == "Royal Straight Flush" or
						hand == "Straight Flush" or
						hand == "Four of a kind" or
						hand == "Full house" or
						hand == "Flush" or
						hand == "Straight" or
						hand == "Three of a kind" or
						hand == "Two pairs" or
						hand == "Two of a kind"
					) and 
					randi() % 3 == 0
				):
					playerAction = "raise"
					if currentPlayer.money <= 10:
						playerActionAmount += 10
					else:
						playerActionAmount = players[currentPlayer.name].money * 0.05
						playerActionAmount += players[currentPlayer.name].money * (randi() % 75 / 100)
				elif(
					(
						hand == "Royal Straight Flush" or
						hand == "Straight Flush" or
						hand == "Four of a kind" or
						hand == "Full house" or
						hand == "Flush" or
						hand == "Straight" or
						hand == "Three of a kind" or
						hand == "Two pairs" or
						hand == "Two of a kind"
					) and 
					randi() % 3 == 0
				):
					playerAction = "call"
				else:
					playerAction = "fold"
			if(
				(
					hand == "Royal Straight Flush" or
					hand == "Straight Flush" or
					hand == "Four of a kind" or
					hand == "Full house" or
					hand == "Flush" or
					hand == "Straight" or
					hand == "Three of a kind" or
					hand == "Two pairs" or
					hand == "Two of a kind"
				) and
				randi() % 2 != 0
			):
				playerAction = "raise"
				if currentPlayer.money <= 10:
					playerActionAmount += 10
				else:
					playerActionAmount = players[currentPlayer.name].money * 0.075
					playerActionAmount += players[currentPlayer.name].money * (randi() % 75 / 100)
	processPlayerTurn(currentPlayer.playerName, playerAction, playerActionAmount)

func processPlayerTurn(playerName, playerAction, playerActionAmount = 0) -> void:
	playPlayerTurn(playerName, playerAction, playerActionAmount)
	if !currentPlayer == "player1":
		pass
	if !checkIfPlayersLeft():
		if table.cards.size() < 5:
			dealCards(1)
			return
		var winner = calculateWinner()
		dealWinnings(winner)
		updatePlayerOrder()

func playPlayerTurn(playerName, playerAction, playerActionAmount) -> void:
	match playerAction:
		"raise":
			table.bets[playerName] += playerActionAmount
			table.highestBet = table.bets[playerName]
			players[playerName].money -= playerActionAmount
			if currentBidState == Poker.BID_STATES.PASS:
				currentBidState = Poker.BID_STATES.CALL
		"call":
			table.bets[playerName] += table.highestBet - table.bets[playerName]
			players[playerName].money -= table.highestBet - table.bets[playerName]
	updatePlayerTurnState(playerName, playerAction)
	updateCurrentPlayer()

func updatePlayerTurnState(playerName, playerAction) -> void:
	for turnState in playersTurnState:
		if playersTurnState[turnState].has(playerName):
			playersTurnState[turnState].erase(playerName)
			break
	playersTurnState[playerAction].append(playerName)

func updateCurrentPlayer() -> void:
	var currentPlayerPosition = playerOrder.find(currentPlayer)
	if currentPlayerPosition == players.size():
		currentPlayer = playerOrder[0]
		return
	currentPlayer = playerOrder[currentPlayerPosition + 1]
	if playersTurnState.folded.has(currentPlayer.playerName):
		updateCurrentPlayer()

func checkIfPlayersLeft() -> bool:
	if(
		(
			playersTurnState.waiting.isEmpty() and
			playersTurnState.passed.size() == players.size()
		) or (
			playersTurnState.waiting.isEmpty() and
			playersTurnState.passed.isEmpty() and
			playersTurnState.raised.isEmpty() and
			playersTurnState.called.size() + playersTurnState.folded.size() == players.size()
		) or (
			playersTurnState.fold.size() == players.size() - 1
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
		"hand": null,
		"cards": null
	}
	for player in players:
		var cards = players[player].cards
		cards.merge(table.cards)
		var hand = calculateHand(cards)
		currentWinningHand = calculateHigherHand(hand, currentWinningHand)
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
						if royalStraightFlush.size == 5:
							return {
								hand: hand,
								cards: royalStraightFlush
							}
			"Straight Flush":
				for card in cards:
					var straightFlush = [card]
					for i in range(1, 5):
						for checkedCard in cards:
							if checkedCard.amount == card.amount + i and checkedCard.suit == card.suit:
								straightFlush.append(checkedCard)
								break
					if straightFlush.size == 5:
						return {
							hand: hand,
							cards: straightFlush
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
							hand: hand,
							cards: fourOfAKind
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
				if pair.size() == 2 and three.size() == 3:
					return {
						hand: hand,
						cards: {
							pair: pair,
							three: three
						}
					}
			"Flush":
				for card in cards:
					var flush = [card]
					for i in range(1, 5):
						for checkedCard in cards:
							if checkedCard.suit == card.suit and !flush.has(checkedCard):
								flush.append(checkedCard)
					if flush.size == 5:
						return {
							hand: hand,
							cards: flush
						}
			"Straight":
				for card in cards:
					var straight = [card]
					for i in range(1, 5):
						for checkedCard in cards:
							if checkedCard.amount == card.amount + i:
								straight.append(checkedCard)
								break
					if straight.size == 5:
						return {
							hand: hand,
							cards: straight
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
							hand: hand,
							cards: threeOfAKind
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
				if firstPair.size() == 2 and secondPair.size() == 2:
					return {
						hand: hand,
						cards: {
							firstPair: firstPair,
							secondPair: secondPair
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
							hand: hand,
							cards: twoOfAKind
						}
			"High card":
				var highestCard = null
				for card in cards:
					if highestCard == null:
						highestCard = card
					if card.amount > highestCard:
						highestCard = card
				return {
					hand: hand,
					cards: highestCard
				}
	push_error("No valid hand!")
	return {}

func calculateHigherHand(newHand, currentWinningHand):
	var newHandTypeRanking = Poker.HANDS.find(newHand.hand)
	var currentWinningHandTypeRanking = Poker.HANDS.find(currentWinningHand.hand)
	if newHandTypeRanking > currentWinningHandTypeRanking:
		return newHand
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
	if typeof(winner) == TYPE_ARRAY:
		pass
	for bet in table.bets:
		players[winner].money += table.bets[bet]

func updatePlayerOrder() -> void:
	playerOrder.push_front(playerOrder.pop_back())
