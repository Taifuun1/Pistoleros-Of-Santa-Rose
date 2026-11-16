extends Node


# Canyon Zone events (Docs/System Design/First Steps Implementation Plan.md,
# commit 2). Choice outcomes are explicit; the encounter choice resolves
# through the shared canyon encounter pool and SceneManager launcher.
var events = {
	"Canyon Cache Raiders": {
		"text": "Three rats are dragging supplies out of a trail cache. They freeze when they see you, teeth bared over the stolen stores.",
		"image_type": "animal",
		"choices": [
			{
				"label": "Draw on the pack",
				"result": "fight_cache_rats",
				"outcome": { "kind": "encounter", "poolZone": "canyon" }
			},
			{
				"label": "Let them scatter",
				"result": "leave_cache_rats",
				"outcome": { "kind": "none" }
			}
		]
	}
}