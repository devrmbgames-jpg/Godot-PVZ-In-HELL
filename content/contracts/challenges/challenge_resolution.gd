extends RefCounted
## Typed result/event payload; live participants remain in Relationships.
class_name ChallengeResolution

var challenge_key: StringName = &""
var result: ChallengeResult.Type = ChallengeResult.Type.NONE
var satisfaction_delta: int = 0
var request_escalation: bool = false
