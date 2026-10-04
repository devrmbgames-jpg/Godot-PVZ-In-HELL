extends RefCounted
## Short DialogueManager response tags mapped to typed player intent.
class_name CustomerDialogueIntent

enum Type {
	NONE,
	HONEST,
	LIE,
	PERSUADE,
	THREAT,
	FLIRT,
	JOKE,
}

const TAG_HONEST: String = "hon"
const TAG_LIE: String = "lie"
const TAG_PERSUADE: String = "prs"
const TAG_THREAT: String = "thr"
const TAG_FLIRT: String = "flr"
const TAG_JOKE: String = "jok"


static func from_tags(tags: PackedStringArray) -> Type:
	for raw_tag: String in tags:
		var tag: String = raw_tag.strip_edges().to_lower()
		match tag:
			TAG_HONEST:
				return Type.HONEST

			TAG_LIE:
				return Type.LIE

			TAG_PERSUADE:
				return Type.PERSUADE

			TAG_THREAT:
				return Type.THREAT

			TAG_FLIRT:
				return Type.FLIRT

			TAG_JOKE:
				return Type.JOKE
	return Type.NONE


static func bit(intent: Type) -> int:
	if intent <= Type.NONE:
		return 0
	return 1 << int(intent)
