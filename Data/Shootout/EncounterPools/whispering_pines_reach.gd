extends Node


# Whispering Pines Reach regular-encounter pool (commit 17; same shared
# pool schema as canyon). The event outcome dispatcher and the
# NewspaperReportBuilder read this same file; weights are authored balance
# data. Only encounters whose enemy composition really exists are listed.
var data = {
	"entries": [
		{ "encounter": "res://Data/Shootout/Encounters/PinesPatrol.gd", "weight": 3 },
		{ "encounter": "res://Data/Shootout/Encounters/PinesWaylay.gd", "weight": 2 },
		{ "encounter": "res://Data/Shootout/Encounters/PinesStandoff.gd", "weight": 1 },
	]
}
