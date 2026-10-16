extends RefCounted
## Detached packing decision; the receiving owner must commit its values before materialization.
## Private fields retain values and shared authored definitions, without live Entity references.
class_name PackageShipmentPlan

var _item: DEF_InventoryItem
var _quantity: int
var _packing: DEF_PackagePacking
var _scene_path: String
var _empty_mass_kg: float
var _gross_mass_kg: float


#region Prepared values
## Created by PackageShipmentRules after capacity validation, before any gameplay mutation.
func _init(item: DEF_InventoryItem, count: int, shell: DEF_PackagePacking, path: String) -> void:
	_item = item
	_quantity = count
	_packing = shell
	_scene_path = path
	_empty_mass_kg = shell.empty_mass_kg
	_gross_mass_kg = _empty_mass_kg + item.cargo_profile.unit_mass_kg * count


func item() -> DEF_InventoryItem:
	return _item


func quantity() -> int:
	return _quantity


func packing() -> DEF_PackagePacking:
	return _packing


func scene_path() -> String:
	return _scene_path


## Captured shell mass in kilograms, for the eventual empty-body transition.
func empty_mass_kg() -> float:
	return _empty_mass_kg


## Captured shell plus payload mass in kilograms; no legacy package recipe is consulted.
func gross_mass_kg() -> float:
	return _gross_mass_kg
#endregion
