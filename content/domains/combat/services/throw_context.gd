extends RefCounted
## Атрибуция намеренного броска принадлежит живой связи источник → R_ThrownBy → инициатор.
class_name ThrowContext


## Находит действующую связь атрибуции броска или null.
static func relationship(source: Entity) -> Relationship:
	if not is_instance_valid(source):
		return null

	for candidate: Relationship in source.relationships:
		if candidate.relation is R_ThrownBy:
			return candidate
	return null


## Captures an eligible contact before either direction can consume the live binding.
static func capture_contact(source: Entity, tick: int) -> ImpactThrowAttribution:
	var binding: Relationship = relationship(source)
	if binding == null or GrabQueries.held_relationship(source) != null:
		return null
	var state: R_ThrownBy = binding.relation as R_ThrownBy
	var actor: Entity = binding.target as Entity
	if state.remaining_seconds <= 0.0 or tick <= state.armed_tick or not is_instance_valid(actor):
		return null
	var snapshot: ImpactThrowAttribution = ImpactThrowAttribution.new()
	snapshot.actor_reference = weakref(actor)
	snapshot.actor_id = actor.id
	return snapshot


## Заменяет атрибуцию инициатором, физическим тактом и авторским сроком.
static func arm(source: Entity, instigator: Entity) -> void:
	if not is_instance_valid(source) or not is_instance_valid(instigator):
		return

	var config: C_ThrowDamage = source.get_component(C_ThrowDamage) as C_ThrowDamage
	if config == null:
		return

	cancel(source)
	var throw_state: R_ThrownBy = R_ThrownBy.new()
	throw_state.remaining_seconds = maxf(0.0, config.window_seconds)
	throw_state.armed_tick = Engine.get_physics_frames()
	if throw_state.remaining_seconds > 0.0:
		source.add_relationship(Relationship.new(throw_state, instigator))


## Идемпотентно снимает действующую связь броска.
static func cancel(source: Entity) -> void:
	if not is_instance_valid(source):
		return

	var active: Relationship = relationship(source)
	if active != null:
		source.remove_relationship(active)
