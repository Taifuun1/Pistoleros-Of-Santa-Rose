extends Node

## The human player's persistent poker bankroll.
## Read when the Poker minigame starts and written back when the game ends
## (leaving the table or busting out).
var money: int = 100