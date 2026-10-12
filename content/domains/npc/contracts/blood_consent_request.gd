extends RefCounted
## Explicit accept/decline intent for one displayed durable blood offer.
class_name BloodConsentRequest

## Current consenting player incarnation.
var actor: Entity = null
## Current district dealer incarnation; stable receipt identity must agree.
var dealer: Entity = null
## Captured stable offer key; UI line IDs and visible text are not transaction keys.
var confirmation_key: StringName = &""
## True accepts the captured current-HP percentage; false explicitly declines.
var accept: bool = false
