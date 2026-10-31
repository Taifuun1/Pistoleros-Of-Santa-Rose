extends JournalTab

## Quests tab. There is no quest journal or objective-target model yet
## (Quests.gd only tracks the main-quest level/rarity), so the tab shows an
## intentional empty state until the quest state API lands.


func refreshTab() -> void:
	showStateMessage()
