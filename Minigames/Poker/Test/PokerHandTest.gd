extends Node

var passed := 0
var failed := 0
var poker

func _ready() -> void:
	poker = load("res://Minigames/Poker/Poker.gd").new()
	runTests()
	print("POKER HAND TESTS: %d passed, %d failed" % [passed, failed])
	get_tree().quit()

func cards(spec: Array) -> Array:
	var result := []
	for entry in spec:
		result.append({ "name": "Test", "amount": entry[0], "suit": entry[1] })
	return result

func check(testName: String, actual, expected) -> void:
	if actual == expected:
		passed += 1
	else:
		failed += 1
		print("FAIL: %s — expected %s, got %s" % [testName, expected, actual])

func runTests() -> void:
	# Royal Straight Flush (4-card variant: 10-J-Q-K suited)
	check("Royal", poker.calculateHand(cards([[10, 0], [11, 0], [12, 0], [13, 0], [2, 1], [5, 2], [9, 3]])).rank, 0)
	check("Royal with extra 9 and Ace", poker.calculateHand(cards([[9, 0], [10, 0], [11, 0], [12, 0], [13, 0], [14, 0], [2, 1]])).rank, 0)
	var notRoyal: Dictionary = poker.calculateHand(cards([[10, 0], [11, 1], [12, 2], [13, 3], [2, 1], [5, 2], [9, 3]]))
	check("Mixed suits not royal", notRoyal.rank != 0, true)

	# Straight Flush (4-card run, suited)
	var straightFlush: Dictionary = poker.calculateHand(cards([[5, 1], [6, 1], [7, 1], [8, 1], [2, 0], [9, 2], [13, 3]]))
	check("Straight flush rank", straightFlush.rank, 1)
	check("Straight flush high card", straightFlush.tiebreak[0], 8)
	# Regression: 5-6-8-J suited was falsely a straight flush (accumulation bug)
	var gappedSuited: Dictionary = poker.calculateHand(cards([[5, 1], [6, 1], [8, 1], [11, 1], [2, 0], [9, 2], [13, 3]]))
	check("Gapped suited cards not straight flush", gappedSuited.rank, 4)

	# Four of a kind
	var four: Dictionary = poker.calculateHand(cards([[9, 0], [9, 1], [9, 2], [9, 3], [13, 0], [2, 1], [5, 2]]))
	check("Four of a kind rank", four.rank, 2)
	check("Four of a kind tiebreak", four.tiebreak, [9, 13])

	# Full house
	var fullHouse: Dictionary = poker.calculateHand(cards([[7, 0], [7, 1], [7, 2], [4, 0], [4, 1], [9, 2], [11, 3]]))
	check("Full house rank", fullHouse.rank, 3)
	check("Full house tiebreak", fullHouse.tiebreak, [7, 4])
	# Regression: three of a kind alone was falsely a full house
	var threeOnly: Dictionary = poker.calculateHand(cards([[7, 0], [7, 1], [7, 2], [4, 0], [9, 1], [11, 2], [13, 3]]))
	check("Three of a kind is not full house", threeOnly.rank, 6)
	var twoTriples: Dictionary = poker.calculateHand(cards([[7, 0], [7, 1], [7, 2], [4, 0], [4, 1], [4, 2], [13, 3]]))
	check("Two triples make full house", twoTriples.tiebreak, [7, 4])

	# Flush (4-card variant)
	var flush: Dictionary = poker.calculateHand(cards([[2, 2], [5, 2], [9, 2], [13, 2], [3, 0], [8, 1], [10, 3]]))
	check("Flush rank", flush.rank, 4)
	check("Flush tiebreak", flush.tiebreak, [13, 9, 5, 2])
	var notFlush: Dictionary = poker.calculateHand(cards([[2, 2], [5, 2], [9, 2], [13, 0], [3, 0], [8, 1], [10, 3]]))
	check("Three suited cards not flush", notFlush.rank != 4, true)

	# Straight (5-card run)
	var straight: Dictionary = poker.calculateHand(cards([[2, 0], [3, 1], [4, 2], [5, 3], [6, 0], [9, 1], [13, 2]]))
	check("Straight rank", straight.rank, 5)
	check("Straight high card", straight.tiebreak[0], 6)
	# Regression: 2-3-5-8-Q was falsely a straight (accumulation bug)
	var gapped: Dictionary = poker.calculateHand(cards([[2, 0], [3, 1], [5, 2], [8, 3], [12, 0], [9, 1], [7, 2]]))
	check("Gapped cards not straight", gapped.rank != 5, true)
	var wheel: Dictionary = poker.calculateHand(cards([[14, 0], [2, 1], [3, 2], [4, 3], [5, 0], [9, 1], [13, 2]]))
	check("Ace-low straight", wheel.rank, 5)
	check("Ace-low straight high card", wheel.tiebreak[0], 5)

	# Two pairs
	var twoPairs: Dictionary = poker.calculateHand(cards([[5, 0], [5, 1], [9, 2], [9, 3], [13, 0], [2, 1], [4, 2]]))
	check("Two pairs rank", twoPairs.rank, 7)
	check("Two pairs tiebreak", twoPairs.tiebreak, [9, 5, 13])

	# One pair
	var pair: Dictionary = poker.calculateHand(cards([[5, 0], [5, 1], [9, 2], [11, 3], [13, 0], [2, 1], [4, 2]]))
	check("Pair rank", pair.rank, 8)
	check("Pair tiebreak", pair.tiebreak, [5, 13, 11, 9])

	# High card (regression: pairless hands errored in the old Two pairs branch)
	var highCard: Dictionary = poker.calculateHand(cards([[2, 0], [5, 1], [9, 2], [11, 3], [13, 0], [4, 1], [7, 2]]))
	check("High card rank", highCard.rank, 9)
	check("High card tiebreak", highCard.tiebreak, [13, 11, 9, 7, 5])

	# Hand comparison: negative when the first score wins, 0 on a tie
	check("Pair of aces beats pair of kings", poker.compareHands([8, 14, 13, 11, 9], [8, 13, 12, 11, 9]) < 0, true)
	check("Identical hands tie", poker.compareHands([8, 14, 13, 11, 9], [8, 14, 13, 11, 9]) == 0, true)
	check("Flush beats straight", poker.compareHands([4, 13, 9, 5, 2], [5, 13]) < 0, true)