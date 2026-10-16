@tool
extends GameDefinition
## Immutable native packaging capacity; selection never increases an already chosen quantity.
class_name DEF_PackagePacking

#region Native shell and capacity
## Native editable variants with the same declared capacity and physical handling contract.
@export_file_path("*.tscn") var scene_variants: Array[String] = []
## Usable interior envelope in metres, independent of the outer visual mesh.
@export var inner_size_m: Vector3 = Vector3(0.5, 0.3, 0.4)
## Fraction of the interior volume usable by payload envelopes, including required padding.
@export_range(0.01, 1.0, 0.01) var usable_volume_ratio: float = 0.7
## Maximum payload unit count; zero capacity is invalid, even if the volume is sufficient.
@export_range(1, 99) var maximum_quantity: int = 4
## Minimum quantity for an ordinary small item; large shells can require a real bulk shipment.
@export_range(1, 99) var minimum_small_quantity: int = 1
## A single item at least this long may bypass the minimum bulk quantity; zero disables bypass.
@export_range(0.0, 10.0, 0.01) var single_item_minimum_length_m: float = 0.0
## Packaging mass without payload, in kilograms; opening restores this shell mass.
@export_range(0.001, 100.0, 0.001) var empty_mass_kg: float = 1.0
## Maximum safe combined payload and shell mass in kilograms.
@export_range(0.001, 1000.0, 0.001, "or_greater") var maximum_gross_mass_kg: float = 100.0
## Gross mass above which the shipment receives a heavy handling mark, in kilograms.
## This authored warning threshold does not replace the holder's Strength/carry policy.
@export_range(0.001, 1000.0, 0.001, "or_greater") var heavy_mark_mass_kg: float = 10.0
#endregion
