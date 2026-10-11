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
}
	

func setRichTextLabel(labelText, color = null, textAlignment = null):
	clear()
	var bbcode = str(labelText)
	if color != null:
		bbcode = bbcode.join(["[color=%s]" % colors[color.to_lower()], "[/color]"])
	if textAlignment != null:
		bbcode = bbcode.join(["[%s]" % textAlignment, "[/%s]" % textAlignment])
	append_text(bbcode)

func setRichTextLabelImage(imgSrc):
	append_text("[img]%s[/img]" % imgSrc)
