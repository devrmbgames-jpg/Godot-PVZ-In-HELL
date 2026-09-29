extends GutTest


func test_history_id_round_trips_diagnostic_fields() -> void:
	var identity: PackageHistoryId = PackageHistoryId.new()
	identity.day_index = 12
	identity.number = 7
	identity.hazard_class = DEF_Package.HazardClass.TOXIC
	identity.size_class = PackageHistoryId.SizeClass.LARGE
	identity.mass_tenths_kg = 300

	var encoded: String = identity.serialize()
	assert_eq(encoded, "12-07-TL08C")
	assert_eq(identity.hash_code(), "TL08C")

	var decoded: PackageHistoryId = PackageHistoryId.parse(encoded)
	assert_not_null(decoded)
	assert_eq(decoded.day_index, 12)
	assert_eq(decoded.number, 7)
	assert_eq(decoded.hazard_class, DEF_Package.HazardClass.TOXIC)
	assert_eq(decoded.size_class, PackageHistoryId.SizeClass.LARGE)
	assert_eq(decoded.mass_tenths_kg, 300)
	assert_almost_eq(decoded.decoded_mass_kg(), 30.0, 0.001)


func test_history_id_rejects_non_reversible_values() -> void:
	assert_null(PackageHistoryId.parse("12-07-ZL08C"))
	assert_null(PackageHistoryId.parse("12-07-TQ08C"))
	assert_null(PackageHistoryId.parse("12-07-TL@@@"))
	assert_null(PackageHistoryId.parse("0-07-TL08C"))
	var too_heavy: PackageHistoryId = PackageHistoryId.new()
	too_heavy.day_index = 1
	too_heavy.number = 1
	too_heavy.mass_tenths_kg = PackageHistoryId.MAX_MASS_TENTHS + 1
	assert_eq(too_heavy.serialize(), "")
