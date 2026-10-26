extends RichTextLabel

var colors = {
	"common": "#bdbdbd",
	"uncommon": "#1f6aad",
	"rare": "#ecec33",
	"epic": "#b00669",
	"legendary": "#f18f1d",
	"white": "#ffffff",
	"offense": "#ff6b52",
	"defense": "#58a6ff",
	"utility": "#7dd87d",
	"status": "#c58aff",
	"keyword": "#ffd6ba",
	"unique": "#cf3662",
	"green": "#00ff00",
	"red": "#ff0000",
	"yellow": "#ffff00",
	"orange": "#ffa500",
}

var rawText = ""
	

func setRichTextLabel(labelText, color = null, textAlignment = null):
	clear()
	rawText = ""
	appendRichTextLabel(labelText, color, textAlignment)


func appendRichTextLabel(labelText, color = null, textAlignment = null):
	var bbcode = str(labelText)
	if color != null:
		bbcode = colorize(bbcode, color)
	if textAlignment != null:
		bbcode = bbcode.join(["[%s]" % textAlignment, "[/%s]" % textAlignment])
	rawText += bbcode
	append_text(bbcode)

func colorize(labelText, colorKey) -> String:
	return str(labelText).join(["[color=%s]" % colors[str(colorKey).to_lower()], "[/color]"])

func setRichTextLabelImage(imgSrc):
	append_text("[img]%s[/img]" % imgSrc)
