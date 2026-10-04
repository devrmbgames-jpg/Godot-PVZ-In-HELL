extends GutTest
## Проверяет обратную связь по фактически применённому урону и освобождение подписок UI.

var _root: Node3D = null
var _world: World = null
var _observer: O_DamageFeedback = null
var _player: Entity = null
var _view: DamageFeedbackView = null
var _received: Array[DamageFeedback] = []


#region Подписанное представление
## Создаёт observer применённого урона, игрока и подписанное представление.
func before_each() -> void:
	_received.clear()
	_root = Node3D.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	_world.add_observer(O_Damage.new())
	_observer = O_DamageFeedback.new()
	_world.add_observer(_observer)
	_observer.received.connect(_on_received)
	_world.add_observer(O_RemoveOnHealthDepleted.new())
	_player = _entity([C_Health.new(), C_PlayerInputController.new()])
	_view = (load("res://content/ui/damage_feedback_view.tscn") as PackedScene).instantiate() as DamageFeedbackView
	_view.player = _player
	_view.observer = _observer
	_root.add_child(_view)


## Удаляет всё дерево UI и World; очищает ECS.world.
func after_each() -> void:
	_root.free()
	ECS.world = null


func _entity(components: Array[Component]) -> Entity:
	var entity: Entity = Entity.new()
	entity.component_resources = components
	_world.add_entity(entity)
	return entity


func _on_received(feedback: DamageFeedback) -> void:
	_received.append(feedback)


func _submit(kind: DamageRequest.Type, amount: float = 5.0, target: Entity = null, source: Entity = null, operation: DamageRequest.Operation = DamageRequest.Operation.DAMAGE) -> void:
	var request: DamageRequest = DamageRequest.new()
	request.target = target if target != null else _player
	request.source = source
	request.instigator = _player
	request.amount = amount
	request.operation = operation
	request.damage_type = kind
	DamageRequestService.submit(request)


#endregion

#region Снимки урона и освобождение UI
## Применённый урон передаёт снимок; токсичность и взрыв имеют разные предупреждения и звук.
func test_applied_hit_snapshot_and_toxic_explosion_warnings_use_distinct_feedback() -> void:
	_submit(DamageRequest.Type.TOXIC)
	assert_eq(_received.size(), 1)
	assert_eq(_received[0].audience, DamageFeedback.Audience.PLAYER)
	assert_eq(_received[0].target_id, _player.id)
	assert_eq(_received[0].amount, 5.0)
	assert_eq((_player.get_component(C_Health) as C_Health).current, 95.0)
	_view._process(0.0)

	var warning: Label = _view.get_node("Warning") as Label
	var sound: AudioStreamPlayer = _view.get_node("Sound") as AudioStreamPlayer
	assert_true(warning.visible)
	assert_true(warning.text.contains("Токсичная зона"))
	assert_eq(warning.modulate, _view.toxic_color)
	var toxic_sound: AudioStream = sound.stream
	assert_false((_view.get_node("Tint") as ColorRect).visible, "Reduced motion is default")
	_submit(DamageRequest.Type.EXPLOSION)
	_view._process(0.0)
	assert_true(warning.text.contains("Взрыв"))
	assert_eq(warning.modulate, _view.explosion_color)
	assert_ne(sound.stream, toxic_sound)
	assert_ne(sound.stream.get_length(), toxic_sound.get_length())
	assert_true(_view.debug_text().contains("Таймер предупреждения"))


## Блокирование, отклонение и лечение не публикуют обратную связь повреждения.
func test_blocked_rejected_or_heal_result_does_not_publish_damage_feedback() -> void:
	var blocked: Entity = _entity([C_NoDamage.new()])
	_submit(DamageRequest.Type.TOXIC, 5.0, _player, blocked)
	_submit(DamageRequest.Type.GENERIC, -5.0)
	(_player.get_component(C_Health) as C_Health).current = 80.0
	_submit(DamageRequest.Type.GENERIC, 10.0, _player, null, DamageRequest.Operation.HEAL)
	assert_true(_received.is_empty())
	assert_eq((_player.get_component(C_Health) as C_Health).current, 90.0)
	assert_false((_view.get_node("Warning") as Label).visible)


## Подпись разрушенной коробки живёт по снимку ID и исчезает по таймеру без ссылки на удалённую Entity.
func test_package_label_survives_destructive_cleanup_without_entity_reference() -> void:
	var identity: C_Package = C_Package.new()
	identity.package_id = "feedback/parcel"
	var package: Entity = _entity([C_Health.new(), identity, C_RemoveOnHealthDepleted.new()])
	var id: String = package.id
	_submit(DamageRequest.Type.EXPLOSION, 200.0, package)
	assert_false(_world.entities.has(package))
	assert_eq(_received.size(), 1)
	assert_eq(_received[0].audience, DamageFeedback.Audience.PACKAGE)
	assert_eq(_received[0].target_id, id)
	assert_eq(_received[0].package_id, "feedback/parcel")
	assert_true(_received[0].depleted)
	assert_eq(_received[0].amount, 100.0)

	var labels: Array[Node] = _view.find_children("WorldDamageLabel*", "Label3D", false, false)
	assert_eq(labels.size(), 1)
	assert_true((labels[0] as Label3D).text.contains("Посылка −100"))
	_view._process(2.0)
	await get_tree().process_frame
	assert_true(_view.find_children("WorldDamageLabel*", "Label3D", false, false).is_empty())


## Отключённое представление не влияет на реальный урон и не накапливает подписи.
func test_disabled_presentation_does_not_change_damage_or_accumulate_labels() -> void:
	_view.enabled = false
	_view._process(0.0)
	_submit(DamageRequest.Type.MELEE, 12.0)
	var package: Entity = _entity([C_Health.new(), C_Package.new()])
	_submit(DamageRequest.Type.IMPACT, 20.0, package)
	assert_eq((_player.get_component(C_Health) as C_Health).current, 88.0)
	assert_eq((package.get_component(C_Health) as C_Health).current, 80.0)
	assert_eq(_received.size(), 2)
	assert_false((_view.get_node("Warning") as Label).visible)
	assert_true(_view.find_children("WorldDamageLabel*", "Label3D", false, false).is_empty())


## Число мировых подписей ограничено; удаление UI освобождает подписку.
func test_world_labels_are_bounded_and_freeing_ui_disconnects_observer() -> void:
	_view.maximum_world_labels = 2
	var package: Entity = _entity([C_Health.new(), C_Package.new()])
	for hit: int in 4:
		_submit(DamageRequest.Type.IMPACT, 1.0, package)
	await get_tree().process_frame
	assert_eq(_view.find_children("WorldDamageLabel*", "Label3D", false, false).size(), 2)
	var connections: int = _observer.get_signal_connection_list("received").size()
	_view.free()
	_view = null
	assert_eq(_observer.get_signal_connection_list("received").size(), connections - 1)
	_submit(DamageRequest.Type.PROJECTILE, 1.0)
	assert_eq(_received.size(), 5)

#endregion
