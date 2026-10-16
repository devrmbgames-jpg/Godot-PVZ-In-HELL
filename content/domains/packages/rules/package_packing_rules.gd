extends RefCounted
## Pure bounded capacity decisions over explicit cargo and authored shells; no world or RNG state.
class_name PackagePackingRules

## Matches the existing package quantity bound; capacity never invents additional payload units.
const MAX_QUANTITY: int = 99
## Authored candidate bound, independent of the number of physical variants in each profile.
const MAX_PROFILES: int = 32


#region Cargo and shell validation
## Rejects malformed cargo before capacity arithmetic; shopping categories are never consulted.
static func valid_cargo(cargo: DEF_ItemCargo) -> bool:
	return (
		cargo != null and cargo.phase in [DEF_ItemCargo.Phase.SOLID, DEF_ItemCargo.Phase.LIQUID]
		and is_finite(cargo.unit_mass_kg) and cargo.unit_mass_kg > 0.0
		and _positive_size(cargo.unit_size_m) and is_finite(_volume(cargo.unit_size_m))
		and _volume(cargo.unit_size_m) > 0.0 and cargo.hazards >= 0
		and cargo.maximum_shipment_quantity >= 1 and cargo.maximum_shipment_quantity <= MAX_QUANTITY
		and (
			cargo.hazards
			& ~(
				DEF_ItemCargo.Hazard.TOXIC | DEF_ItemCargo.Hazard.FLAMMABLE
				| DEF_ItemCargo.Hazard.EXPLOSIVE
			)
		)
		== 0
	)


## Validates data only; native scene/root compatibility belongs to the materialization boundary.
static func valid_profile(profile: DEF_PackagePacking) -> bool:
	if profile == null or profile.key == &"" or profile.scene_variants.is_empty():
		return false
	if (
		not _positive_size(profile.inner_size_m) or not is_finite(profile.usable_volume_ratio)
		or profile.usable_volume_ratio <= 0.0 or profile.usable_volume_ratio > 1.0
		or profile.maximum_quantity < 1 or profile.maximum_quantity > MAX_QUANTITY
		or profile.minimum_small_quantity < 1
		or profile.minimum_small_quantity > profile.maximum_quantity
		or not is_finite(profile.single_item_minimum_length_m)
		or profile.single_item_minimum_length_m < 0.0 or not is_finite(profile.empty_mass_kg)
		or profile.empty_mass_kg <= 0.0 or not is_finite(profile.maximum_gross_mass_kg)
		or profile.maximum_gross_mass_kg <= profile.empty_mass_kg
	):
		return false
	var paths: Dictionary[String, bool] = { }
	for path: String in profile.scene_variants:
		if not GameplayResourcePaths.is_entity_scene_path(path) or paths.has(path):
			return false
		paths[path] = true
	return is_finite(_volume(profile.inner_size_m)) and _volume(profile.inner_size_m) > 0.0


## Bounded envelope/volume classes, not universal 3D packing; rotation ignores author axis order.
static func accepts(profile: DEF_PackagePacking, cargo: DEF_ItemCargo, quantity: int) -> bool:
	if (
		not valid_cargo(cargo) or not valid_profile(profile) or quantity < 1
		or quantity > profile.maximum_quantity or quantity > cargo.maximum_shipment_quantity
	):
		return false
	var unit_axes: Array[float] = _axes(cargo.unit_size_m)
	var shell_axes: Array[float] = _axes(profile.inner_size_m)
	for index: int in unit_axes.size():
		if unit_axes[index] > shell_axes[index]:
			return false
	if quantity < profile.minimum_small_quantity:
		if (
			quantity != 1 or profile.single_item_minimum_length_m <= 0.0
			or unit_axes.back() < profile.single_item_minimum_length_m
		):
			return false
	var payload_volume: float = _volume(cargo.unit_size_m) * quantity
	var capacity: float = _volume(profile.inner_size_m) * profile.usable_volume_ratio
	var gross_mass: float = profile.empty_mass_kg + cargo.unit_mass_kg * quantity
	return (
		is_finite(payload_volume) and payload_volume <= capacity
		and (is_finite(gross_mass) and gross_mass <= profile.maximum_gross_mass_kg)
	)
#endregion


#region Canonical smallest compatible shell
## Chooses the smallest adequate shell; equal capacities use the unique authored key as tie-break.
## Missing/ambiguous profiles reject rather than making an order depend on catalog array order.
static func choose(
	profiles: Array[DEF_PackagePacking],
	cargo: DEF_ItemCargo,
	quantity: int,
) -> DEF_PackagePacking:
	if profiles.size() > MAX_PROFILES:
		return null
	var counts: Dictionary[StringName, int] = { }
	for profile: DEF_PackagePacking in profiles:
		if valid_profile(profile):
			counts[profile.key] = counts.get(profile.key, 0) + 1
	var selected: DEF_PackagePacking = null
	for profile: DEF_PackagePacking in profiles:
		if not valid_profile(profile) or counts[profile.key] != 1:
			continue
		if not accepts(profile, cargo, quantity):
			continue
		if selected == null or _before(profile, selected):
			selected = profile
	return selected


static func _positive_size(size_m: Vector3) -> bool:
	return size_m.is_finite() and size_m.x > 0.0 and size_m.y > 0.0 and size_m.z > 0.0


static func _axes(size_m: Vector3) -> Array[float]:
	var axes: Array[float] = [size_m.x, size_m.y, size_m.z]
	axes.sort()
	return axes


static func _volume(size_m: Vector3) -> float:
	return size_m.x * size_m.y * size_m.z


static func _before(first: DEF_PackagePacking, second: DEF_PackagePacking) -> bool:
	var first_volume: float = _volume(first.inner_size_m)
	var second_volume: float = _volume(second.inner_size_m)
	if first_volume != second_volume:
		return first_volume < second_volume
	return String(first.key) < String(second.key)
#endregion
