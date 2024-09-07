extends RichTextLabel

var colors = {  }

#func _ready():
	#for _spellData in spellData.spellData:
		#if !_spellData.match("spellDirections"):
			#colors[_spellData] = spellData.spellData[_spellData].color
	#
	#colors.common = "#c1c1c1"
	#colors.uncommon = "#1f7dc4"
	#colors.rare = "#eae326"
	#colors.legendary = "#ff8900"
	#
	#colors.accessory = "#ed13c2"
	#colors.armor = "#0d45ec"
	#colors.comestible = "#056613"
	#colors.gem = "#11ea75"
	#colors.miscellaneous = "#ffffff"
	#colors.potion = "#4dec0d"
##	colors.ring = "#1fc437"
	#colors.rune = "#8019e7"
	#colors.scroll = "#91a9ef"
	#colors.tool = "#c95720"
	#colors.wand = "#ed1313"
	#colors.weapon = "#84002a"
	#
	#colors.flavorMessage = "#ef379a"
	#
	#colors.green = "#2dd400"
	#colors.red = "#cf0000"
	

func setRichTextLabel(labelText, color = null, textAlignment = null):
	clear()
	var bbcode = str(labelText)
	if color != null:
		bbcode = bbcode.join(["[color=%s]" % colors[color.to_lower()], "[/color]"])
	if textAlignment != null:
		bbcode = bbcode.join(["[%s]" % textAlignment, "[/%s]" % textAlignment])
	append_text(bbcode)
		#push_error("Error appending bbcode.")

func setRichTextLabelImage(imgSrc):
	append_text("[img]{%s}[/img]" % imgSrc)

#func setRichTextLabelForGameConsole(_critterName, _text):
	#var _bbcode = str(_critterName) + ": "
	#_bbcode = _bbcode.join(["[color=%s]" % colors.flavorMessage, "[/color]"])
	#_bbcode += str(_text)
	#if append_text(_bbcode) != OK:
		#push_error("Error appending bbcode.")
