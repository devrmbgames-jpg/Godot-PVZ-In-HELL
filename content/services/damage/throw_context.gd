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


## Заменяет атрибуцию инициатором, физическим тактом и авторским сроком.
static func arm(source: Entity, instigator: Entity) -> void:
	if not is_instance_valid(source) or not is_instance_valid(instigator):
		return

	var config: C_ThrowDamage = source.get_component(C_ThrowDamage) as C_ThrowDamage
	if config == null:
		return

	cancel(source)
	var data: R_ThrownBy = R_ThrownBy.new()
	data.remaining_seconds = maxf(0.0, config.window_seconds)
	data.armed_tick = Engine.get_physics_frames()
	if data.remaining_seconds > 0.0:
		source.add_relationship(Relationship.new(data, instigator))


## Идемпотентно снимает действующую связь броска.
static func cancel(source: Entity) -> void:
	if not is_instance_valid(source):
		return

	var active: Relationship = relationship(source)
	if active != null:
		source.remove_relationship(active)
