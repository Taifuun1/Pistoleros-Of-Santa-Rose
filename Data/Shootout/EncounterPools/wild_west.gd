extends Node


# Wild West Zone regular-encounter pool (Docs/System Design/Location Vendors
# Implementation.md, Newspaper data). The future encounter launcher and
# NewspaperReportBuilder read this same file; weights are authored balance data.
# Only encounters whose enemy composition really exists are listed here.
var data = {
	"entries": [
		{ "encounter": "res://Data/Shootout/Encounters/CanyonRats.gd", "weight": 3 },
		{ "encounter": "res://Data/Shootout/Encounters/CanyonRatNest.gd", "weight": 1 },
	]
}