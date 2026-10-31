extends JournalTab

## Settings tab. There is no authoritative settings or save service yet, so
## the tab shows an intentional unavailable state instead of editing engine
## settings directly.


func refreshTab() -> void:
	showStateMessage()
