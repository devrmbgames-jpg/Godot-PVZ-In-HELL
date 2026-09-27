extends RefCounted
## One normalized developer-console target. Data only; resolution belongs to DebugTargetResolver.
class_name DebugTarget

enum Kind {
	INVALID,
	ENTITY,
	PACKAGE,
	VISIT,
}

var query: String = ""
var kind: Kind = Kind.INVALID
var entity: Entity = null
var package_id: String = ""
var registration: PackageRegistrationRecord = null
var visit: CustomerVisit = null
var error: String = ""
