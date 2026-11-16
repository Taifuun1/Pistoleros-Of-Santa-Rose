extends Node

## The human player's persistent poker bankroll.
## Read when the Poker minigame starts and written back when the game ends
## (leaving the table or busting out).
const DEFAULT_MONEY := 100

var money: int = DEFAULT_MONEY


## New Game: restore the canonical poker bankroll.
func resetForNewGame() -> void:
	money = DEFAULT_MONEY