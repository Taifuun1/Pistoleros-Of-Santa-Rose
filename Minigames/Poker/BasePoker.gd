extends Node2D
class_name BasePoker

## Player actions, also used as the betting turn states.
## The integer values are bound from the Poker scene's button signals.
enum ACTION {
	WAITING,
	PASSED,
	RAISED,
	CALLED,
	FOLDED,
}