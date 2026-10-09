extends GutTest
## Proves compiler copies isolate nested state while preserving immutable tuning references.

## Mutable record with a deliberately non-exported initial field.
class RuntimeRecord extends Resource:
	## Initial state must survive a recipe copy without becoming shared between builds.
	var counter: int = 7


## Transient typed records may also use RefCounted without Resource serialization.
class RuntimeTicket extends RefCounted:
	## Mutable request state must not alias when it forms part of a Component recipe.
	var count: int = 11


## Minimal data-only Component exercising shared-record aliasing inside one aggregate.
class RecordRecipe extends Component:
	## First reference to the aggregate's mutable record.
	var first_record: RuntimeRecord = null
	## Second reference deliberately aliases the same record inside this Component.
	var second_record: RuntimeRecord = null
	## Typed transient records require the same isolation as exported Resources.
	var tickets: Array[RuntimeTicket] = []


#region Independent compiler recipes
## Nested person/memory state is fresh per build; its immutable Profile remains shared.
func test_two_builds_isolate_nested_records_and_retain_definition_references() -> void:
	var source: C_District = C_District.new()
	source.definition = DEF_District.new()
	var person: NpcRecord = NpcRecord.new()
	person.npc_id = &"fixture/person"
	person.profile = DEF_NpcProfile.new()
	var memory: NpcMemory = NpcMemory.new()
	memory.incident_id = &"fixture/incident"
	person.memories = [memory]
	source.people = [person]

	var first: C_District = EntityRecipeRules.copy_component(source) as C_District
	var second: C_District = EntityRecipeRules.copy_component(source) as C_District
	assert_eq(first.definition, source.definition)
	assert_eq(first.people[0].profile, person.profile)
	assert_ne(first.people[0], person)
	assert_ne(first.people[0], second.people[0])
	first.people[0].memories[0].day = 12
	first.people.append(NpcRecord.new())
	assert_eq(source.people.size(), 1)
	assert_eq(second.people.size(), 1)
	assert_eq(memory.day, 1)
	assert_eq(second.people[0].memories[0].day, 1)


## Canonical Resource-based Definitions remain shared without acquiring a second runtime copy.
func test_resource_based_impact_profile_remains_an_immutable_definition_reference() -> void:
	var source: C_ImpactReceiver = C_ImpactReceiver.new()
	var profile: DEF_ImpactProfile = DEF_ImpactProfile.new()
	profile.minimum_speed = 3.0
	source.profile = profile
	var first: C_ImpactReceiver = EntityRecipeRules.copy_component(source) as C_ImpactReceiver
	var second: C_ImpactReceiver = EntityRecipeRules.copy_component(source) as C_ImpactReceiver
	assert_ne(first, source)
	assert_ne(first, second)
	assert_same(first.profile, profile)
	assert_same(second.profile, profile)
	assert_eq(first.profile.minimum_speed, 3.0)


## A typed mutable Dictionary preserves its type and never changes another build's damage policy.
func test_typed_dictionary_isolation_preserves_authored_initial_values() -> void:
	var source: C_DamageResistance = C_DamageResistance.new()
	source.multipliers[DamageRequest.Type.FIRE] = 0.5
	var first: C_DamageResistance = EntityRecipeRules.copy_component(source) as C_DamageResistance
	var second: C_DamageResistance = EntityRecipeRules.copy_component(source) as C_DamageResistance
	first.multipliers[DamageRequest.Type.FIRE] = 0.0
	assert_eq(source.multipliers[DamageRequest.Type.FIRE], 0.5)
	assert_eq(second.multipliers[DamageRequest.Type.FIRE], 0.5)
	assert_true(first.multipliers.is_typed())


## Packed collections are copied explicitly instead of sharing a mutable container across builds.
func test_packed_collections_do_not_alias_between_compiler_recipes() -> void:
	var source: C_District = C_District.new()
	source.delivery_considered = ["visit/one"]
	var first: C_District = EntityRecipeRules.copy_component(source) as C_District
	var second: C_District = EntityRecipeRules.copy_component(source) as C_District
	first.delivery_considered.append("visit/two")
	assert_eq(source.delivery_considered, PackedStringArray(["visit/one"]))
	assert_eq(second.delivery_considered, PackedStringArray(["visit/one"]))


## Non-export record fields survive copying and intra-aggregate aliasing has one fresh record.
func test_nonexport_record_state_and_intraaggregate_alias_are_preserved() -> void:
	var source: RecordRecipe = RecordRecipe.new()
	source.first_record = RuntimeRecord.new()
	source.first_record.counter = 19
	source.second_record = source.first_record
	var first: RecordRecipe = EntityRecipeRules.copy_component(source) as RecordRecipe
	var second: RecordRecipe = EntityRecipeRules.copy_component(source) as RecordRecipe
	assert_eq(first.first_record.counter, 19)
	assert_eq(first.first_record, first.second_record)
	assert_ne(first.first_record, source.first_record)
	assert_ne(first.first_record, second.first_record)
	first.first_record.counter = 2
	assert_eq(source.first_record.counter, 19)
	assert_eq(second.first_record.counter, 19)


## Scripted RefCounted data aggregates receive independent instances and retain initial state.
func test_typed_refcounted_records_do_not_alias_between_builds() -> void:
	var source: RecordRecipe = RecordRecipe.new()
	var ticket: RuntimeTicket = RuntimeTicket.new()
	ticket.count = 23
	source.tickets = [ticket]
	var first: RecordRecipe = EntityRecipeRules.copy_component(source) as RecordRecipe
	var second: RecordRecipe = EntityRecipeRules.copy_component(source) as RecordRecipe
	assert_eq(first.tickets[0].count, 23)
	assert_ne(first.tickets[0], ticket)
	assert_ne(first.tickets[0], second.tickets[0])
	first.tickets[0].count = 2
	assert_eq(ticket.count, 23)
	assert_eq(second.tickets[0].count, 23)


## The calendar recipe retains its durable data and every build owns a separate clock aggregate.
func test_owned_clock_recipe_keeps_saved_values_without_sharing_mutable_state() -> void:
	var source: C_DayCycle = C_DayCycle.new()
	source.clock.elapsed_ticks = 17
	source.clock.tick_remainder = 0.625
	source.clock.world_seed = -42
	var first: C_DayCycle = EntityRecipeRules.copy_component(source) as C_DayCycle
	var second: C_DayCycle = EntityRecipeRules.copy_component(source) as C_DayCycle
	assert_eq(first.clock.elapsed_ticks, 17)
	assert_eq(first.clock.tick_remainder, 0.625)
	assert_eq(first.clock.world_seed, -42)
	assert_ne(first.clock, source.clock)
	assert_ne(first.clock, second.clock)
	first.clock.elapsed_ticks = 21
	assert_eq(source.clock.elapsed_ticks, 17)
	assert_eq(second.clock.elapsed_ticks, 17)
#endregion
