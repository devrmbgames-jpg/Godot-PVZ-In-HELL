extends RefCounted
## Committed ACTIVE session fact; condition capability setup may consume it synchronously or defer.
class_name ChallengeActivated

## Typed activation boundary published after phase and elapsed mutation.
const EVENT: StringName = &"challenge_activated"
## Immutable authored Definition identity; queued consumers reject superseded session setup.
var definition: DEF_Challenge
