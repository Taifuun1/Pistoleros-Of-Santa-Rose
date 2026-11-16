extends RefCounted
class_name NewGameCoordinator

## New Game domain reset coordinator (Docs/System Design/First Steps
## Implementation Plan.md, commit 5). SceneManager owns modal/context/music
## cleanup and the Overworld transition; this resets each domain to its
## canonical initial state through the service's own resetForNewGame().
##
## Order matters: Party first (the baseline the world and quests are consistent
## with), then the world/quest services, then Vendors and Discovery, then the
## transient minigame/Poker sessions.

const DOMAIN_ORDER := [
	"Party",
	"Quests",
	"Locations",
	"Overworld",
	"Cutscene",
	"OverworldEvents",
	"Vendors",
	"Discovery",
	"PokerMoney",
	"Poker",
	"MusicPlayer",
]


## Resets every present domain. Returns a report mapping {domain: bool} so a
## caller/test can see which services were actually found and reset. Missing
## services are reported as false rather than failing New Game.
static func resetDomains(root: Node, seedValue := 0) -> Dictionary:
	var report := {}
	for domainName in DOMAIN_ORDER:
		var service = root.get_node_or_null(domainName) if root != null else null
		if service == null or !service.has_method("resetForNewGame"):
			report[domainName] = false
			continue
		if domainName == "Vendors":
			service.resetForNewGame(seedValue)
		else:
			service.resetForNewGame()
		report[domainName] = true
	return report
