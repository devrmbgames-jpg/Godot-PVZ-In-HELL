extends RefCounted
## Explicit first-contact request; the handler checks authored eligibility and input focus.
class_name CustomerGreetingRequest

## Shared request channel for isolated scheduling and the native wait-for-parcel leaf.
const EVENT: StringName = &"customer_greeting_requested"
