extends JournalTab

## Inventory & equipment tab. Capacity, stacking, dropping and equipment
## command APIs still need their design; until then the tab shows an
## intentional unavailable state rather than a read-only copy of
## Party.inventory.


func refreshTab() -> void:
	showStateMessage()
