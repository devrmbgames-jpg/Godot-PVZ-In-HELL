extends RefCounted
## Ресурсы Kenney; XML читается один раз на лист только при отсутствии готового .res.
class_name PromptAtlasCatalog

const SOURCE: String = "res://resources/kenney/kenney_input_prompts/"
const OUTPUT: String = "res://content/resources/input_prompts/"
const SHEETS: Dictionary[String, String] = {
	"keyboard_mouse": "keyboard-&-mouse",
	"xbox_series": "xbox-series",
	"playstation_series": "playstation-series",
	"steam_controller": "steam-controller",
	"steam_deck": "steam-deck",
}
const SCALES: PackedStringArray = ["default", "double"]

static var _textures: Dictionary[String, AtlasTexture] = {}
static var _parsed: Dictionary[String, Dictionary] = {}


static func atlas_path(family: String, name: String, scale: String = "default") -> String:
	return OUTPUT + family + "/" + scale + "/" + name + ".res"


static func texture(family: String, name: String, scale: String = "default") -> AtlasTexture:
	if not SHEETS.has(family) or not scale in SCALES or name.is_empty():
		return null
	var path: String = atlas_path(family, name, scale)
	if _textures.has(path):
		return _textures[path]
	var atlas: AtlasTexture = null
	if ResourceLoader.exists(path):
		atlas = load(path) as AtlasTexture
	else:
		atlas = entries(family, scale).get(name) as AtlasTexture
	_textures[path] = atlas
	return atlas


## Таблица leaf-ресурсов для генератора и runtime fallback; один общий Texture2D на лист.
static func entries(family: String, scale: String) -> Dictionary[String, AtlasTexture]:
	var result: Dictionary[String, AtlasTexture] = {}
	if not SHEETS.has(family) or not scale in SCALES:
		return result
	var key: String = family + "/" + scale
	if _parsed.has(key):
		result.assign(_parsed[key])
		return result
	var folder: String = SOURCE + family + "/"
	var xml: XMLParser = XMLParser.new()
	var error: Error = xml.open(folder + SHEETS[family] + "_sheet_" + scale + ".xml")
	if error != OK:
		_parsed[key] = result
		return result
	var sheet: Texture2D = null
	while xml.read() == OK:
		if xml.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		if xml.get_node_name() == "TextureAtlas":
			var image_path: String = folder + xml.get_named_attribute_value("imagePath")
			if ResourceLoader.exists(image_path):
				sheet = load(image_path) as Texture2D
		elif xml.get_node_name() == "SubTexture" and sheet != null:
			var name: String = xml.get_named_attribute_value("name")
			var region: Rect2 = Rect2(
				float(xml.get_named_attribute_value("x")), float(xml.get_named_attribute_value("y")),
				float(xml.get_named_attribute_value("width")), float(xml.get_named_attribute_value("height")),
			)
			if name.is_empty() or region.size.x <= 0 or region.size.y <= 0 or result.has(name):
				push_error("Invalid/duplicate prompt entry: %s/%s" % [key, name])
				continue
			if not Rect2(Vector2.ZERO, sheet.get_size()).encloses(region):
				push_error("Prompt outside atlas: %s/%s" % [key, name])
				continue
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = region
			atlas.filter_clip = true
			result[name] = atlas
	_parsed[key] = result
	return result
