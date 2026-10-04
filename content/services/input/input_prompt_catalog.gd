extends RefCounted
## Целые спрайты Kenney: outline при наличии, иначе обычный PNG той же кнопки. XML не используется.
class_name InputPromptCatalog

const SOURCE: String = "res://resources/kenney/kenney_input_prompts/"
const FAMILIES: PackedStringArray = ["keyboard_mouse", "xbox_series", "playstation_series", "steam_controller", "steam_deck"]

static var _textures: Dictionary[String, Texture2D] = {}


## Путь к исходному спрайту; отсутствующая кнопка возвращает пустую строку для fallback устройства.
static func sprite_path(family: String, name: String) -> String:
	if not family in FAMILIES or name.is_empty() or name.get_file() != name:
		return ""

	var base: String = SOURCE + family + "/Default/" + name
	var outline: String = base + "_outline.png"
	if ResourceLoader.exists(outline, "Texture2D"):
		return outline

	var plain: String = base + ".png"
	return plain if ResourceLoader.exists(plain, "Texture2D") else ""


## Кеширует импортированный Texture2D без обёртки AtlasTexture и без нарезки изображения.
static func texture(family: String, name: String) -> Texture2D:
	var path: String = sprite_path(family, name)
	if path.is_empty():
		return null
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D
	return _textures[path]
