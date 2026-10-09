@tool
extends Entity
## Авторские точки обслуживания и физическая область коробок; не решает исход выдачи.
class_name E_DeliveryCounter


## Физические коробки, пересекающие DeliveryArea в текущем снимке physics; принадлежность проверяет сервис.
func parcels() -> Array[Entity]:
	var area: Area3D = get_node("DeliveryArea") as Area3D
	var found: Array[Entity] = []
	for body: Node3D in area.get_overlapping_bodies():
		var entity: Entity = body as Node as Entity
		if entity != null and entity.has_component(C_Package):
			found.append(entity)
	return found


## Мировая авторская точка подхода получателя к стойке.
func entry_position() -> Vector3:
	return (get_node("Entry") as Node3D).global_position


## Мировая авторская точка ожидания обслуживания.
func waiting_position() -> Vector3:
	return (get_node("Waiting") as Node3D).global_position


## Обновляет авторскую табличку без изменения состояния заказа.
func show_message(message: String) -> void:
	(get_node("Sign") as Label3D).text = message
