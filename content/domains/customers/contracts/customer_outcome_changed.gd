extends RefCounted
## Committed visit-record change; live appearance state is read only by its owning consumer.
class_name CustomerOutcomeChanged

## Targeted session fact channel, never a wildcard dispatcher.
const EVENT: StringName = &"customer_outcome_changed"
## Stable record identity within the owning CustomerFlow aggregate.
var visit_id: StringName = &""
## Committed operation or lifecycle reason for diagnostics.
var reason: StringName = &""
