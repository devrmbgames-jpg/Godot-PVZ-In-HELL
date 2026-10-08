extends GutTest
## Проверки сохранения завершённых действий и постоянных опасностей без повторных эффектов и восстановления устаревших связей.

var _root: Node = null
var _world: World = null


#region Подготовка и очистка
## Создаёт сессию и наблюдателей геометрии/связей опасностей в изолированном World.
func before_each() -> void:
	_root = Node.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	var session: Entity = Entity.new()
	session.name = "Session"
	session.component_resources = [C_DayCycle.new(), C_Wallet.new()]
	_root.add_child(session)
	session.owner = _root
	_root.set_meta(PlacedIdentityRules.WORLD_ID_META, &"fixture")
	session.set_meta(PlacedIdentityRules.LOCAL_ID_META, StringName(session.name))
	assert_true(PlacedIdentityRules.compile_for(_root).is_empty())
	_world.add_entity(session, null, false)
	_world.add_observer(O_ToxicAreaSetup.new())
	_world.add_observer(O_ExplosionSetup.new())
	_world.add_observer(O_HazardFollowLifecycle.new())


## Очищает World и освобождает тестовый хост, сбрасывая ECS.world.
func after_each() -> void:
	_world.purge(false)
	_root.free()
	ECS.world = null


func _valve() -> E_InteractionTestValve:
	var valve: E_InteractionTestValve = (load("res://content/entities/props/interaction_test_valve.tscn") as PackedScene).instantiate() as E_InteractionTestValve
	valve.name = "Valve"
	_root.add_child(valve)
	valve.owner = _root
	_root.set_meta(PlacedIdentityRules.WORLD_ID_META, &"fixture")
	valve.set_meta(PlacedIdentityRules.LOCAL_ID_META, StringName("valve_%d" % _world.entities.size()))
	assert_true(PlacedIdentityRules.compile_for(_root).is_empty())
	_world.add_entity(valve, null, false)
	return valve


func _progress(valve: E_InteractionTestValve, id: StringName) -> ProlongedInteractionProgress:
	var state: C_ProlongedInteraction = valve.get_component(C_ProlongedInteraction) as C_ProlongedInteraction
	if state == null:
		state = C_ProlongedInteraction.new()
		valve.add_component(state)
	var progress: ProlongedInteractionProgress = ProlongedInteractionProgress.new()
	progress.action_id = id
	for action: DEF_InteractionAction in (valve.get_component(C_InteractionActionSet) as C_InteractionActionSet).actions:
		if action.action_id == id:
			progress.timing = action.timing
	state.actions.append(progress)
	return progress


#endregion

#region Завершённые действия и отображение прогресса
## Завершённое NEVER-действие и эффект восстанавливаются без повторного сигнала активации.
func test_never_completion_and_effect_restore_without_executing_again() -> void:
	var valve: E_InteractionTestValve = _valve()
	var progress: ProlongedInteractionProgress = _progress(valve, &"test_valve_never")
	assert_true(ProlongedProgressSolver.advance(progress, progress.timing, progress.timing.duration_seconds, true))
	valve.activate()
	assert_true(ProlongedProgressSolver.commit_success(progress, progress.timing))
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	valve.activate()
	(valve.get_component(C_ProlongedInteraction) as C_ProlongedInteraction).actions.clear()
	watch_signals(valve)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_true(valve.is_active())
	assert_signal_not_emitted(valve, "activated")
	progress = (valve.get_component(C_ProlongedInteraction) as C_ProlongedInteraction).actions[0]
	assert_eq(progress.action_id, &"test_valve_never")
	assert_eq(progress.phase, ProlongedInteractionProgress.Phase.COMPLETED)
	assert_false(ProlongedProgressSolver.advance(progress, progress.timing, 10.0, true))
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_eq((valve.get_component(C_ProlongedInteraction) as C_ProlongedInteraction).actions.size(), 1)


## Ночь сбрасывает незавершённый прогресс, сохраняя зафиксированное NEVER-действие.
func test_night_discards_incomplete_decay_and_never_but_retains_committed_action() -> void:
	var valve: E_InteractionTestValve = _valve()
	var decay: ProlongedInteractionProgress = _progress(valve, &"test_valve_decay")
	var never: ProlongedInteractionProgress = _progress(valve, &"test_valve_never")
	ProlongedProgressSolver.advance(decay, decay.timing, 0.8, true)
	ProlongedProgressSolver.advance(never, never.timing, 0.9, true)
	NightResetService.reset()
	assert_eq(decay.fraction, 0.0)
	assert_eq(never.fraction, 0.0)
	assert_eq(decay.phase, ProlongedInteractionProgress.Phase.IDLE)
	assert_eq(never.phase, ProlongedInteractionProgress.Phase.IDLE)
	ProlongedProgressSolver.advance(never, never.timing, never.timing.duration_seconds, true)
	assert_true(ProlongedProgressSolver.commit_success(never, never.timing))
	NightResetService.reset()
	assert_eq(never.phase, ProlongedInteractionProgress.Phase.COMPLETED)
	assert_eq(never.fraction, 1.0)


## Неизвестное или повторяемое действие в списке завершённых отклоняется до мутации мира.
func test_unknown_or_repeatable_completed_action_fails_before_day_or_effect_changes() -> void:
	var valve: E_InteractionTestValve = _valve()
	for id: StringName in [&"missing", &"test_valve_decay"]:
		var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
		for record: Dictionary in snapshot.entities:
			if String(record.key) == ActorIdentityRules.key_for(valve, _root):
				record.completed_actions = [id]
		assert_false(WorldSnapshotService.restore(snapshot, _root))
		assert_eq(DayPhaseQueries.current().day_index, 1)
		assert_false(valve.is_active())


## Начальное значение и непосредственные переключения публикуют только фактические изменения прогресса.
func test_valve_progress_initial_and_immediate_toggle_emit_only_changed_values() -> void:
	var valve: E_InteractionTestValve = _valve()
	watch_signals(valve)
	await get_tree().process_frame
	assert_signal_emitted_with_parameters(valve, "progress_changed", [0.0])
	assert_signal_not_emitted(valve, "activated")
	valve.activate()
	assert_signal_emitted_with_parameters(valve, "progress_changed", [1.0], 1)
	valve.activate()
	valve._process(0.0)
	assert_signal_emit_count(valve, "progress_changed", 3)
	assert_signal_emit_count(valve, "activated", 2)
	assert_eq(valve.get_progress(), 0.0)


## Видимый прогресс и колесо следуют затуханию/сбросу без повторного применения завершённого эффекта.
func test_valve_progress_follows_rotation_decay_and_oncomplete_reset_without_reactivation() -> void:
	var valve: E_InteractionTestValve = _valve()
	valve.mode = E_InteractionTestValve.Mode.HOLD_DECAY
	var wheel: Node3D = valve.get_node("Wheel") as Node3D
	var rest: Basis = wheel.basis
	var progress: ProlongedInteractionProgress = _progress(valve, &"test_valve_decay")
	ProlongedProgressSolver.advance(progress, progress.timing, progress.timing.duration_seconds / 2.0, true)
	valve._process(0.0)
	assert_eq(valve.get_progress(), 0.5)
	assert_true(wheel.basis.is_equal_approx(rest * Basis(Vector3.UP, PI / 2.0)))
	assert_string_contains((valve.get_node("ProgressStatus") as Label3D).text, "4.0 с")
	ProlongedProgressSolver.interrupt(progress, progress.timing)
	InteractionInputFixture.decay(valve, 1.0)
	valve._process(0.0)
	assert_almost_eq(valve.get_progress(), 0.4125, 0.00001)
	valve.mode = E_InteractionTestValve.Mode.HOLD_ON_COMPLETE

	var reset_progress: ProlongedInteractionProgress = _progress(valve, &"test_valve_on_complete")
	watch_signals(valve)
	assert_true(ProlongedProgressSolver.advance(reset_progress, reset_progress.timing, reset_progress.timing.duration_seconds, true))
	valve.activate()
	assert_eq(valve.get_progress(), 1.0)
	assert_signal_emitted_with_parameters(valve, "progress_changed", [1.0])
	assert_true(ProlongedProgressSolver.commit_success(reset_progress, reset_progress.timing))
	valve._process(0.0)
	assert_eq(valve.get_progress(), 0.0)
	assert_signal_emit_count(valve, "activated", 1)
	assert_signal_emit_count(valve, "progress_changed", 2)
	assert_true(wheel.basis.is_equal_approx(rest))


## Загрузка NEVER обновляет сигнал прогресса и положение колеса, не вызывая активацию.
func test_valve_progress_saved_never_restores_signal_and_wheel_without_executing_effect() -> void:
	var valve: E_InteractionTestValve = _valve()
	valve.mode = E_InteractionTestValve.Mode.HOLD_NEVER
	var progress: ProlongedInteractionProgress = _progress(valve, &"test_valve_never")
	assert_true(ProlongedProgressSolver.advance(progress, progress.timing, progress.timing.duration_seconds, true))
	valve.activate()
	assert_true(ProlongedProgressSolver.commit_success(progress, progress.timing))
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	(valve.get_component(C_ProlongedInteraction) as C_ProlongedInteraction).actions.clear()
	(valve.get_component(C_InteractionToggle) as C_InteractionToggle).active = false
	valve._process(0.0)
	watch_signals(valve)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	valve._process(0.0)
	assert_eq(valve.get_progress(), 1.0)
	assert_true(valve.is_active())
	assert_signal_emitted_with_parameters(valve, "progress_changed", [1.0])
	assert_signal_not_emitted(valve, "activated")
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	valve._process(0.0)
	assert_signal_emit_count(valve, "progress_changed", 1)
	NightResetService.reset()
	valve._process(0.0)
	assert_eq(valve.get_progress(), 1.0)
	assert_signal_emit_count(valve, "progress_changed", 1)


#endregion

#region Постоянные опасности и настройки тела
func _hazard(path: String, persistent: bool) -> Entity:
	var entity: Entity = (load(path) as PackedScene).instantiate() as Entity
	var hazard: C_Hazard = C_Hazard.new()
	hazard.definition = (entity as E_Hazard).definition
	hazard.request_id = "save/" + entity.name
	var lifetime: C_HazardLifetime = C_HazardLifetime.new()
	lifetime.remaining_seconds = 42.5
	lifetime.persistent = persistent
	_world.add_entity(entity, [hazard, lifetime])
	return entity


## Постоянный токсин сохраняет таймер, виновника, связь следования, иммунитет и геометрию.
func test_persistent_toxic_clock_follow_attribution_and_geometry_survive_recreation() -> void:
	var valve: E_InteractionTestValve = _valve()
	var id: String = valve.id
	var toxin: Entity = _hazard("res://content/entities/hazards/toxic_area.tscn", true)
	var hazard: C_Hazard = toxin.get_component(C_Hazard) as C_Hazard
	hazard.origin = valve
	hazard.instigator = valve
	hazard.origin_id = id
	hazard.instigator_id = id
	toxin.add_component(C_NoDamage.new())

	var follow: R_HazardFollow = R_HazardFollow.new()
	follow.local_offset.origin = Vector3(2, 0, 0)
	HazardFollowService.replace(toxin, valve, follow)
	(toxin.get_component(C_ToxicArea) as C_ToxicArea).tick_elapsed = 0.35
	var key: String = ActorIdentityRules.key_for(toxin, _root)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	_world.remove_entity(toxin)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	for entity: Entity in _world.entities:
		if ActorIdentityRules.key_for(entity, _root) == key:
			toxin = entity
	assert_true(is_instance_valid(toxin))
	hazard = toxin.get_component(C_Hazard) as C_Hazard
	assert_eq(hazard.origin, valve)
	assert_eq(hazard.instigator, valve)
	assert_eq(hazard.instigator_id, id)
	assert_true(toxin.has_component(C_NoDamage))
	assert_eq((toxin.get_component(C_HazardLifetime) as C_HazardLifetime).remaining_seconds, 42.5)
	assert_eq((toxin.get_component(C_ToxicArea) as C_ToxicArea).tick_elapsed, 0.35)

	var restored_binding: Relationship = HazardFollowService.binding(toxin)
	assert_not_null(restored_binding)
	assert_eq(restored_binding.target, valve)
	assert_eq((restored_binding.relation as R_HazardFollow).local_offset.origin, Vector3(2, 0, 0))
	assert_eq(((toxin as E_ToxicArea).get_shape().shape as SphereShape3D).radius, (hazard.definition as DEF_ToxicArea).radius)


## Восстановленная связь остаётся Relationship и удаляет эффект только после потери владельца.
func test_follow_restore_preserves_despawn_effect_until_owner_relationship_is_lost() -> void:
	var valve: E_InteractionTestValve = _valve()
	var toxin: Entity = _hazard("res://content/entities/hazards/toxic_area.tscn", true)
	var follow: R_HazardFollow = R_HazardFollow.new()
	follow.on_loss = DEF_Hazard.OwnerLoss.Despawn
	HazardFollowService.replace(toxin, valve, follow)
	var saved: Dictionary = PersistentHazardState.capture(toxin, _root)
	var entities: Dictionary[String, Entity] = {}
	entities[ActorIdentityRules.key_for(valve, _root)] = valve
	PersistentHazardState.restore(saved, toxin, entities)
	assert_true(EntityAvailability.contains(toxin, _world))
	assert_false(toxin.has_component(R_HazardFollow))
	assert_eq(HazardFollowService.binding(toxin).target, valve)
	assert_eq(toxin.relationships.size(), 1)
	_world.remove_entity(valve)
	assert_null(HazardFollowService.binding(toxin))
	assert_false(EntityAvailability.contains(toxin, _world))


## Отключённая опасность соблюдает detach/despawn при потере владельца до повторного включения.
func test_disabled_follow_effect_honours_owner_loss_and_cannot_resume_damage() -> void:
	var valve: E_InteractionTestValve = _valve()
	var detached: Entity = _hazard("res://content/entities/hazards/toxic_area.tscn", true)
	var despawned: Entity = _hazard("res://content/entities/hazards/toxic_area.tscn", true)
	var despawned_id: String = despawned.id
	for effect: Entity in [detached, despawned]:
		var follow: R_HazardFollow = R_HazardFollow.new()
		follow.on_loss = DEF_Hazard.OwnerLoss.Despawn if effect == despawned else DEF_Hazard.OwnerLoss.Detach
		HazardFollowService.replace(effect, valve, follow)
		_world.disable_entity(effect)
	_world.remove_entity(valve)
	await get_tree().process_frame
	assert_false(EntityAvailability.contains(despawned, _world))
	assert_false(_world.entities.any(func(entity: Entity) -> bool: return entity.id == despawned_id))
	assert_true(_world.entities.has(detached))
	assert_null(HazardFollowService.binding(detached))
	_world.enable_entity(detached)
	assert_true(EntityAvailability.contains(detached, _world))


## Восстановление независимого эффекта отменяет ранее отложенное удаление по потере владельца.
func test_independent_restore_cancels_deferred_owner_loss_retirement() -> void:
	var owner: E_InteractionTestValve = _valve()
	var toxin: Entity = _hazard("res://content/entities/hazards/toxic_area.tscn", true)
	var follow: R_HazardFollow = R_HazardFollow.new()
	follow.on_loss = DEF_Hazard.OwnerLoss.Despawn
	HazardFollowService.replace(toxin, owner, follow)
	_world.disable_entity(toxin)
	_world.remove_entity(owner)

	var lifetime: C_HazardLifetime = toxin.get_component(C_HazardLifetime) as C_HazardLifetime
	assert_true(lifetime.owner_loss_pending)
	var entities: Dictionary[String, Entity] = {}
	PersistentHazardState.restore({"origin": "", "instigator": ""}, toxin, entities)
	assert_false(lifetime.owner_loss_pending)
	await get_tree().process_frame
	assert_true(_world.entities.has(toxin))
	assert_null(HazardFollowService.binding(toxin))
	_world.enable_entity(toxin)
	assert_true(EntityAvailability.contains(toxin, _world))


## Ночная очистка завершает отложенное удаление отключённой опасности до захвата снимка.
func test_night_drains_disabled_owner_loss_before_persistent_snapshot_capture() -> void:
	var customer: E_InteractionTestValve = _valve()
	customer.add_component(C_CustomerAgent.new())
	var toxin: Entity = _hazard("res://content/entities/hazards/toxic_area.tscn", true)
	var key: String = ActorIdentityRules.key_for(toxin, _root)
	var follow: R_HazardFollow = R_HazardFollow.new()
	follow.on_loss = DEF_Hazard.OwnerLoss.Despawn
	HazardFollowService.replace(toxin, customer, follow)
	_world.disable_entity(toxin)
	NightResetService.reset()
	assert_false(_world.entities.has(toxin))

	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	for record: Dictionary in snapshot.entities:
		assert_ne(String(record.key), key)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_true(_world.query.with_all([C_Hazard]).execute().is_empty())


## Уже разрешённый взрыв не получает новый запрос разрешения после загрузки.
func test_resolved_persistent_explosion_does_not_rearm_resolution_gate_on_load() -> void:
	var blast: Entity = _hazard("res://content/entities/hazards/explosion.tscn", true)
	(blast.get_component(C_Explosion) as C_Explosion).resolved = true
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_true((blast.get_component(C_Explosion) as C_Explosion).resolved)
	assert_false((blast.get_component(C_HazardLifetime) as C_HazardLifetime).awaiting_resolution)


## Отключённый токсин восстанавливает форму и маску до применения конечного disabled-состояния.
func test_disabled_persistent_toxin_rebuilds_geometry_before_final_disable() -> void:
	var toxin: Entity = _hazard("res://content/entities/hazards/toxic_area.tscn", true)
	var id: String = toxin.id
	_world.disable_entity(toxin)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	_world.remove_entity(toxin)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	toxin = _world.get_entity_by_id(id)
	assert_not_null(toxin)
	assert_false(toxin.enabled)
	_world.enable_entity(toxin)

	var definition: DEF_ToxicArea = (toxin.get_component(C_Hazard) as C_Hazard).definition as DEF_ToxicArea
	assert_eq(((toxin as E_ToxicArea).get_shape().shape as SphereShape3D).radius, definition.radius)
	assert_eq((toxin as E_ToxicArea).get_area().collision_mask, definition.collision_mask)


## Пропущенный компонент или несовместимый профиль опасности отклоняется без изменения World.
func test_null_wrong_profile_or_omitted_hazard_component_fails_without_mutation() -> void:
	var toxin: Entity = _hazard("res://content/entities/hazards/toxic_area.tscn", true)
	for invalid: String in ["null", "wrong", "omitted"]:
		var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
		for record: Dictionary in snapshot.entities:
			if String(record.entity_id) != toxin.id:
				continue

			var components: Array = record.components as Array
			for index: int in components.size():
				if SaveDataCodec.component_script(String(components[index].type)) != C_Hazard:
					continue
				if invalid == "omitted":
					components.remove_at(index)
				elif invalid == "null":
					(components[index].fields as Dictionary).definition = null
				else:
					(components[index].fields as Dictionary).definition = SaveDataCodec.encode(load("res://content/definitions/gameplay/hazards/def_parcel_blast.tres") as DEF_Explosion)
				break

		var count: int = _world.entities.size()
		assert_false(WorldSnapshotService.restore(snapshot, _root), invalid)
		assert_eq(DayPhaseQueries.current().day_index, 1)
		assert_eq(_world.entities.size(), count)
		assert_true(_world.entities.has(toxin))


## Ночь удаляет временные опасности и применяет правила потери владельца к постоянным.
func test_night_removes_temporary_hazards_and_applies_persistent_owner_loss() -> void:
	var valve: E_InteractionTestValve = _valve()
	var temporary: Entity = _hazard("res://content/entities/hazards/toxic_area.tscn", false)
	var detached: Entity = _hazard("res://content/entities/hazards/toxic_area.tscn", true)
	var despawned: Entity = _hazard("res://content/entities/hazards/toxic_area.tscn", true)
	for entity: Entity in [detached, despawned]:
		var follow: R_HazardFollow = R_HazardFollow.new()
		follow.on_loss = DEF_Hazard.OwnerLoss.Despawn if entity == despawned else DEF_Hazard.OwnerLoss.Detach
		HazardFollowService.replace(entity, valve, follow)
	_world.remove_entity(valve)
	NightResetService.reset()
	assert_false(_world.entities.has(temporary))
	assert_false(_world.entities.has(despawned))
	assert_true(_world.entities.has(detached))
	assert_null(HazardFollowService.binding(detached))


## Загрузка незафиксированного предмета снимает старый anchor и возвращает сохранённые настройки тела.
func test_loading_unfixed_snapshot_clears_old_anchor_and_restores_body_policy() -> void:
	var box: Entity = (load("res://content/entities/props/anchorable_test_box.tscn") as PackedScene).instantiate() as Entity
	_world.add_entity(box)
	var body: RigidBody3D = box as Node as RigidBody3D
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	var fixed: C_PlayerAnchored = C_PlayerAnchored.new()
	fixed.snapshot = AnchoredBodySnapshot.new()
	fixed.snapshot.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	fixed.snapshot.can_sleep = false
	box.add_component(fixed)
	body.freeze = true
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_false(box.has_component(C_PlayerAnchored))
	assert_false(body.freeze)
	assert_eq(body.freeze_mode, RigidBody3D.FREEZE_MODE_KINEMATIC)
	assert_false(body.can_sleep)

#endregion

#region Deferred hazard scheduling
## Renewal before flush invalidates an old expiry; the next due expiry retires the live aggregate.
func test_hazard_manual_flush_revalidates_renewed_lifetime() -> void:
	var effect: Entity = _hazard("res://content/entities/hazards/toxic_area.tscn", true)
	var lifetime: C_HazardLifetime = effect.get_component(C_HazardLifetime) as C_HazardLifetime
	lifetime.remaining_seconds = 0.1
	var owner: S_HazardLifetime = S_HazardLifetime.new()
	owner.group = "HazardFixture"
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.add_system(owner)
	_world.process(0.2, owner.group)
	lifetime.remaining_seconds = 20.0
	_world.flush_command_buffers()
	assert_true(EntityAvailability.contains(effect, _world))
	assert_false(effect.is_queued_for_deletion())

	_world.process(20.0, owner.group)
	_world.flush_command_buffers()
	assert_false(_world.entity_to_archetype.has(effect))
	assert_true(effect.is_queued_for_deletion())


## Restored/replaced lifetime state survives an expiry command captured for the old Component.
func test_hazard_manual_flush_rejects_replaced_lifetime() -> void:
	var effect: Entity = _hazard("res://content/entities/hazards/toxic_area.tscn", true)
	var previous: C_HazardLifetime = effect.get_component(C_HazardLifetime) as C_HazardLifetime
	previous.remaining_seconds = 0.1
	var owner: S_HazardLifetime = S_HazardLifetime.new()
	owner.group = "HazardFixture"
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.add_system(owner)
	_world.process(0.2, owner.group)

	effect.remove_component(C_HazardLifetime)
	var replacement: C_HazardLifetime = C_HazardLifetime.new()
	replacement.remaining_seconds = 20.0
	effect.add_component(replacement)
	_world.flush_command_buffers()
	assert_true(EntityAvailability.contains(effect, _world))
	assert_eq(replacement.remaining_seconds, 20.0)


## Disabled effects participate in cleanup even though the active EntityAvailability predicate excludes them.
func test_hazard_lifetime_owner_retires_disabled_effect() -> void:
	var effect: Entity = _hazard("res://content/entities/hazards/toxic_area.tscn", true)
	_world.disable_entity(effect)
	var owner: S_HazardLifetime = S_HazardLifetime.new()
	owner.group = "HazardFixture"
	_world.add_system(owner)
	_world.process(0.0, owner.group)
	assert_false(_world.entity_to_archetype.has(effect))
	assert_true(effect.is_queued_for_deletion())


## A lost-owner sample cannot despawn an effect whose live follow binding was replaced before flush.
func test_hazard_follow_manual_flush_preserves_rebound_effect() -> void:
	var original_owner: Entity = _valve()
	var replacement_owner: Entity = _valve()
	var effect: Entity = _hazard("res://content/entities/hazards/toxic_area.tscn", true)
	var follow: R_HazardFollow = R_HazardFollow.new()
	follow.on_loss = DEF_Hazard.OwnerLoss.Despawn
	HazardFollowService.replace(effect, original_owner, follow)
	_world.disable_entity(original_owner)
	var owner: S_HazardFollow = S_HazardFollow.new()
	owner.group = "HazardFixture"
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.add_system(owner)
	_world.process(0.0, owner.group)

	HazardFollowService.replace(effect, replacement_owner, follow.duplicate() as R_HazardFollow)
	_world.flush_command_buffers()
	assert_true(EntityAvailability.contains(effect, _world))
	assert_eq(HazardFollowService.binding(effect).target, replacement_owner)
#endregion
