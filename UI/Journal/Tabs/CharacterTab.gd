extends JournalTab

## Character tab. Party member data exists in Party.gd, but the shared
## effective-stat calculation is not exposed yet; the tab shows an
## intentional unavailable state until it can read the same values as
## Shootouts.


func refreshTab() -> void:
	showStateMessage()
