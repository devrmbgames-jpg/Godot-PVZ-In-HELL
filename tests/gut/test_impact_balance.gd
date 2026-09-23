extends GutTest
## Regression checks for R08 parcel toughness, impact caps and authored thresholds.

const REGULAR: DEF_ImpactProfile = preload(
	"res://content/definitions/gameplay/impact_default.tres"
)
const FRAGILE: DEF_ImpactProfile = preload(
	"res://content/definitions/gameplay/impact_fragile.tres"
)
const SUPPLY: DEF_Delivery = preload(
	"res://content/definitions/gameplay/deliveries/def_delivery_morning_supply.tres"
)


func test_light_impacts_are_absorbed_by_regular_parcels() -> void:
	var regular: ImpactResult = ImpactCalculation.evaluate(10.0, 10.0, 40.0, REGULAR)
	var fragile: ImpactResult = ImpactCalculation.evaluate(10.0, 10.0, 40.0, FRAGILE)
	assert_true(regular.qualifies)
	assert_eq(regular.amount, 0.0)
	assert_true(fragile.qualifies)
	assert_gt(fragile.amount, 0.0)


func test_regular_hit_cap_blocks_single_impact_destruction() -> void:
	assert_almost_eq(ImpactCalculation.cap_damage(100.0, 100.0, REGULAR), 7.5, 0.001)
	assert_eq(ImpactCalculation.cap_damage(5.0, 100.0, REGULAR), 5.0)


func test_fragile_hit_cap_scales_with_effective_max_health() -> void:
	assert_almost_eq(FRAGILE.max_hp_fraction_per_hit, 0.15, 0.001)
	assert_almost_eq(ImpactCalculation.cap_damage(100.0, 100.0, FRAGILE), 15.0, 0.001)
	assert_almost_eq(ImpactCalculation.cap_damage(100.0, 40.0, FRAGILE), 6.0, 0.001)


func test_fragile_profiles_are_more_sensitive_than_regular_profiles() -> void:
	var regular: ImpactResult = ImpactCalculation.evaluate(10.0, 10.0, 80.0, REGULAR)
	var fragile: ImpactResult = ImpactCalculation.evaluate(10.0, 10.0, 80.0, FRAGILE)
	assert_true(regular.qualifies)
	assert_true(fragile.qualifies)
	assert_gt(fragile.amount, regular.amount)


func test_fragile_supply_uses_earlier_visible_damage_threshold() -> void:
	var regular_definition: DEF_Package = DEF_Package.new()
	assert_almost_eq(regular_definition.damaged_health_ratio, 0.60, 0.001)
	var checked_fragile: int = 0
	var checked_regular: int = 0
	for definition: DEF_Package in SUPPLY.packages:
		if definition.tags & DEF_Package.Tag.FRAGILE:
			checked_fragile += 1
			assert_almost_eq(definition.damaged_health_ratio, 0.85, 0.001)
		else:
			checked_regular += 1
			assert_almost_eq(definition.damaged_health_ratio, 0.60, 0.001)
	assert_eq(checked_fragile, 4)
	assert_eq(checked_regular, 4)
