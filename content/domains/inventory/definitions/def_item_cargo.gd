@tool
extends GameDefinition
## Immutable physical cargo facts, independent of shopping category and inventory use effects.
class_name DEF_ItemCargo

enum Phase {
	SOLID,
	LIQUID,
}

enum Hazard {
	NONE = 0,
	TOXIC = 1,
	FLAMMABLE = 2,
	EXPLOSIVE = 4,
}

#region Physical unit facts
## Physical phase of the actual payload; a container scene does not change this value.
@export var phase: Phase = Phase.SOLID
## Mass of one complete item, including its own bottle/barrel, in kilograms.
@export_range(0.001, 1000.0, 0.001, "or_greater") var unit_mass_kg: float = 1.0
## Required orthogonal unit envelope in metres; packing may rotate its axes.
@export var unit_size_m: Vector3 = Vector3(0.1, 0.1, 0.1)
## Actual payload hazard mask; unrelated to recipient preference or package size.
@export_flags("Toxic:1", "Flammable:2", "Explosive:4") var hazards: int = Hazard.NONE
## Requires fragile handling regardless of whether the payload is liquid.
@export var fragile: bool = false
#endregion
