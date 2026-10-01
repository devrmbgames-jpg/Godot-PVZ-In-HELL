extends RefCounted
class_name ChallengeResult

enum Type { NONE, SUCCESS, FAILURE, CANCELLED }


static func key(result: Type) -> StringName:
	match result:
		Type.SUCCESS: return &"success"
		Type.FAILURE: return &"failure"
		Type.CANCELLED: return &"cancelled"
	return &""
