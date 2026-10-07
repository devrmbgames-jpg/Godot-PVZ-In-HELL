extends RefCounted
## Committed cleanup of challenge participation; cancellation can release a pending settlement.
class_name ChallengeSessionClosed

## Separate lifecycle fact from a newly resolved success/failure result.
const EVENT: StringName = &"challenge_session_closed"
## Authored identity of the closed challenge session.
var challenge_key: StringName = &""
## Retained terminal result, including cancellation.
var result: ChallengeResult.Type = ChallengeResult.Type.NONE
