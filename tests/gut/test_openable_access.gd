extends GutTest
## Проверяет доступ по живому владению ключом и предложения движения отдельно от физического исполнения.


## Тестовый поставщик разрешает оценку доступа, но отказывает при фиксации расхода.
class RefusingConsumption extends DEF_HeldItemAccess:
	## Возвращает отказ без удаления ключа или изменения его владения.
	func consume(_actor: Entity, _item: Entity) -> bool:
		return false

var _world: World
var _actor: Entity
var _target: Entity
var _state: C_Openable
var _requirement: DEF_AccessRequirement


#region Тестовое окружение и ключ
## Создаёт закрытый замок и авторское требование ключа в отдельном World.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_actor = _entity([C_GrabControl.new()])
	_state = C_Openable.new()
	_state.locked = true
	_requirement = DEF_AccessRequirement.new()
	_requirement.required_item_id = &"warehouse_key"
	_state.access = _requirement
	_target = _entity([_state])
	_state = _target.get_component(C_Openable) as C_Openable


## Удаляет World и освобождает глобальную ссылку ECS.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null


func _entity(components: Array[Component]) -> Entity:
	var entity: Entity = Entity.new()
	entity.component_resources = components
	_world.add_entity(entity)
	return entity


func _key(slot: C_Grabbable.HoldSlot = C_Grabbable.HoldSlot.LEFT_HAND) -> Entity:
	var identity: C_AccessItem = C_AccessItem.new()
	identity.item_id = &"warehouse_key"
	identity.tags = [&"brass", &"warehouse"]
	var item: Entity = _entity([identity])
	var grip: R_HeldBy = R_HeldBy.new()
	grip.slot = slot
	item.add_relationship(Relationship.new(grip, _actor))

	var control: C_GrabControl = _actor.get_component(C_GrabControl) as C_GrabControl
	if slot == C_Grabbable.HoldSlot.LEFT_HAND:
		control.held_left = item
	else:
		control.held_right = item
	return item


#endregion

#region Доступ и расходование
## ID и все обязательные теги должны принадлежать одному подходящему предмету.
func test_id_and_all_tags_must_match_one_item() -> void:
	var identity: C_AccessItem = C_AccessItem.new()
	identity.item_id = &"warehouse_key"
	identity.tags = [&"brass"]
	_requirement.required_tags = [&"brass", &"warehouse"]
	assert_false(ItemAccessRules.matches(identity, _requirement))
	identity.tags.append(&"warehouse")
	assert_true(ItemAccessRules.matches(identity, _requirement))
	identity.item_id = &"other_key"
	assert_false(ItemAccessRules.matches(identity, _requirement))
	_requirement.required_item_id = &""
	assert_true(ItemAccessRules.matches(identity, _requirement), "Tags alone are supported")


## Ключ в любой руке даёт доступ по Relationship; устаревший кеш руки не даёт.
func test_either_hand_grants_access_but_stale_cache_does_not() -> void:
	for slot: C_Grabbable.HoldSlot in [C_Grabbable.HoldSlot.LEFT_HAND, C_Grabbable.HoldSlot.RIGHT_HAND]:
		var item: Entity = _key(slot)
		assert_true(ItemAccessService.evaluate(_actor, _requirement).is_allowed())
		item.remove_all_relationships()
		assert_false(ItemAccessService.evaluate(_actor, _requirement).is_allowed())


## Отпирание требует ключ, не открывает дверь и не перемещает физическое тело.
func test_unlock_does_not_open_and_no_key_is_not_available() -> void:
	var action: DEF_OpenableAction = DEF_OpenableAction.new()
	action.operation = OpenableService.Operation.UNLOCK
	assert_false(action.is_available(_actor, _target, _target))
	_key()
	assert_true(action.complete(_actor, _target, _target))
	assert_false(_state.locked)
	assert_false(_state.requested_open)
	assert_eq(_state.actual_fraction, 0.0)
	assert_false(action.complete(_actor, _target, _target), "Unlock is a single transition")
	assert_true(OpenableService.request(_actor, _target, OpenableService.Operation.OPEN))
	assert_true(_state.requested_open)
	assert_eq(_state.actual_fraction, 0.0, "Requesting motion never teleports the body")


## После удаления ключа действие повторно проверяет доступ и оставляет замок закрытым.
func test_key_removed_after_prompt_cannot_unlock() -> void:
	var item: Entity = _key()
	assert_true(OpenableService.can_request(_actor, _target, OpenableService.Operation.UNLOCK))
	item.remove_all_relationships()
	assert_false(OpenableService.request(_actor, _target, OpenableService.Operation.UNLOCK))
	assert_true(_state.locked)


## Расходование включается явно и удаляет только выбранный подходящий ключ.
func test_consumption_is_opt_in_and_removes_only_matching_item() -> void:
	var left: Entity = _key()
	var right: Entity = _key(C_Grabbable.HoldSlot.RIGHT_HAND)
	assert_true(OpenableService.request(_actor, _target, OpenableService.Operation.UNLOCK))
	assert_true(GrabQueries.entity_available(left))
	_state.locked = true
	_requirement.consume_item = true
	assert_true(OpenableService.request(_actor, _target, OpenableService.Operation.UNLOCK))
	assert_false(GrabQueries.entity_available(left))
	assert_true(GrabQueries.entity_available(right))


## Пустое требование с расходованием отклоняется, не забирая произвольный предмет.
func test_empty_consuming_requirement_never_consumes_arbitrary_item() -> void:
	_key()
	_requirement.required_item_id = &""
	_requirement.consume_item = true
	assert_eq(ItemAccessService.evaluate(_actor, _requirement).outcome, AccessResult.Outcome.INVALID_REQUIREMENT)
	assert_false(OpenableService.request(_actor, _target, OpenableService.Operation.UNLOCK))


## Отказ поставщика расходовать ключ оставляет замок и владение предметом неизменными.
func test_provider_refusal_keeps_lock_and_item_unchanged() -> void:
	var item: Entity = _key()
	var config: C_ItemAccess = C_ItemAccess.new()
	config.providers = [RefusingConsumption.new()]
	_actor.add_component(config)
	_requirement.consume_item = true
	assert_true(OpenableService.can_request(_actor, _target, OpenableService.Operation.UNLOCK))
	assert_false(OpenableService.request(_actor, _target, OpenableService.Operation.UNLOCK))
	assert_true(_state.locked)
	assert_true(GrabQueries.entity_available(item))
	assert_not_null(GrabQueries.held_relationship(item))


#endregion

#region Запрос и фактическое движение
## Предложение движения ограничено диапазоном; реальная доля меняется только отчётом физического исполнителя.
func test_motion_proposal_is_bounded_and_does_not_advance_blocked_state() -> void:
	_state.locked = false
	_state.motion = DEF_OpenableMotion.new()
	_state.motion.duration_seconds = 2.0
	_state.requested_open = true
	assert_eq(OpenableMotionSolver.proposed_fraction(_state, 1.0), 0.5)
	assert_eq(_state.actual_fraction, 0.0)
	assert_eq(OpenableMotionSolver.proposed_fraction(_state, 100.0), 1.0)
	assert_true(OpenableService.report_fraction(_state, 0.3))
	assert_true(OpenableService.request(_actor, _target, OpenableService.Operation.CLOSE))
	assert_eq(OpenableMotionSolver.proposed_fraction(_state, 1.0), 0.0)
	assert_false(OpenableService.report_fraction(_state, NAN))
	assert_false(OpenableService.report_fraction(_state, 1.1))
	assert_eq(_state.actual_fraction, 0.3)
	_state.locked = true
	assert_eq(OpenableMotionSolver.proposed_fraction(_state, 1.0), 0.3)


## Один контракт интерполяции поддерживает сдвиг ящика и поворот двери.
func test_same_motion_contract_supports_translation_and_rotation() -> void:
	var motion: DEF_OpenableMotion = DEF_OpenableMotion.new()
	motion.open_transform.origin = Vector3(0.0, 0.0, 0.6)
	assert_eq(OpenableMotionSolver.local_transform(motion, 0.5).origin, Vector3(0.0, 0.0, 0.3))
	motion.open_transform = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO)
	var halfway: Transform3D = OpenableMotionSolver.local_transform(motion, 0.5)
	assert_almost_eq(halfway.basis.get_euler().y, PI / 4.0, 0.0001)

#endregion
