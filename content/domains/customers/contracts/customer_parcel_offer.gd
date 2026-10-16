extends RefCounted
## Transient synchronous offer receipt; live ownership stays in the existing Relationships.
class_name CustomerParcelOffer

enum Source {
	HELD = 1,
	COUNTER = 2,
}

const ALL_SOURCES: int = Source.HELD | Source.COUNTER

## Captured World incarnation; never persisted or retained by a Component.
var world: World
## Borrowed receiver, revalidated against the captured World.
var customer: E_NpcCharacter
## Exact transient role incarnation captured during selection.
var agent: C_CustomerAgent
## Existing journal record; a replacement with the same ID invalidates this offer.
var visit: CustomerVisit
## Borrowed physical parcel; checked again immediately before the domain commit.
var parcel: Entity
## Player offering the parcel; also supplies control/modal/death eligibility for counter offers.
var actor: Entity
## Physical source; HELD requires the actor's actual hand/carry Relationship.
var source: Source = Source.HELD
## Required native station for COUNTER; null for HELD.
var counter: E_DeliveryCounter
## Advisory selection score in square metres; commit recalculates reach and source eligibility.
var distance_squared: float = INF
## Advisory query result; commit repeats the check instead of trusting this captured result.
var check: PackageDeliveryCheck
