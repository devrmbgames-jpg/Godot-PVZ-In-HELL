extends RefCounted
## Зрение по нескольким точкам и ограниченные звуковые события без всеведения о цели.
class_name NpcPerceptionService

const EYE_HEIGHT: float = 1.5
const TORSO_HEIGHT: float = 0.9
const LOWER_BODY_HEIGHT: float = 0.25
const TORSO_HEAD_FRACTION: float = 0.6
const SHOULDER_OFFSET: float = 0.22
const SIGHT_MASK: int = 31

#region Зрение
## Проверяет физическую видимость с учётом зрения, света и частичного прикрытия.
static func can_see(observer: Entity, target: Entity, profile: DEF_NpcProfile, allow_dead_target: bool = false) -> bool:
	var target_available: bool = is_instance_valid(target) and is_instance_valid(ECS.world) and ECS.world.entities.has(target) if allow_dead_target else GrabService.holder_available(target)
	if observer == target or not target_available or not GrabService.holder_available(observer):
		return false

	var observer_body: PhysicsBody3D = observer as Node as PhysicsBody3D
	var target_body: PhysicsBody3D = target as Node as PhysicsBody3D
	if observer_body == null or target_body == null or not observer_body.is_inside_tree() or not target_body.is_inside_tree():
		return false

	var eye: Vector3 = _head_point(observer, observer_body)
	var target_head: Vector3 = _head_point(target, target_body)
	var head_height: float = maxf(LOWER_BODY_HEIGHT, target_head.y - target_body.global_position.y)
	var torso_height: float = minf(TORSO_HEIGHT, head_height * TORSO_HEAD_FRACTION)
	var torso: Vector3 = target_body.global_position + Vector3.UP * torso_height
	var target_offset: Vector3 = torso - eye
	var distance: float = target_offset.length()
	# Отсечь дальние цели и цели позади до проверки зон света и лучей зрения.
	if distance > maxf(profile.near_recognition_range, profile.vision_range):
		return false

	var head: Node3D = observer_body.get_node_or_null("HeadY") as Node3D
	var forward: Vector3 = -(head.global_basis.z if head != null else observer_body.global_basis.z).normalized()
	if distance > profile.near_recognition_range and forward.dot(target_offset.normalized()) < cos(deg_to_rad(profile.vision_angle * 0.5)):
		return false

	var dark_fraction: float = 1.0 if profile.rule_for(DEF_NpcTrait.Kind.DARK_PREDATOR) != null else profile.dark_vision_fraction
	if distance > maxf(profile.near_recognition_range, profile.vision_range * dark_fraction):
		var exposure: float = NpcLightingService.exposure_at(torso, [target_body.get_rid()])
		var sight_range: float = maxf(profile.near_recognition_range, profile.vision_range * lerpf(dark_fraction, 1.0, exposure))
		if distance > sight_range:
			return false

	var shoulder: Vector3 = target_body.global_basis.x.normalized() * SHOULDER_OFFSET
	var lower_body: Vector3 = target_body.global_position + Vector3.UP * minf(LOWER_BODY_HEIGHT, torso_height * 0.5)
	var points: Array[Vector3] = [target_head, torso, torso + shoulder, torso - shoulder, lower_body]
	for point: Vector3 in points:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, point, SIGHT_MASK)
		query.exclude = [observer_body.get_rid()]
		var hit: Dictionary = observer_body.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.get("collider") == target_body:
			return true
	return false

static func _head_point(actor: Entity, physical: PhysicsBody3D) -> Vector3:
	var character: E_PhysicalCharacter = actor as E_PhysicalCharacter
	if character != null and is_instance_valid(character.head_axis_x):
		return character.head_axis_x.global_position
	return physical.global_position + Vector3.UP * EYE_HEIGHT

## Проверяет предмет или авторскую точку по тем же правилам света, сектора и препятствий.
static func can_see_point(observer: E_DistrictNpc, point: Vector3, profile: DEF_NpcProfile, target: Entity = null) -> bool:
	if not GrabService.holder_available(observer):
		return false

	var eye: Vector3 = observer.global_position + Vector3.UP * EYE_HEIGHT
	var offset: Vector3 = point - eye
	var distance: float = offset.length()
	if distance > maxf(profile.near_recognition_range, profile.vision_range):
		return false

	var head: Node3D = observer.get_node_or_null("HeadY") as Node3D
	var forward: Vector3 = -(head.global_basis.z if head != null else observer.global_basis.z).normalized()
	if distance > profile.near_recognition_range and forward.dot(offset.normalized()) < cos(deg_to_rad(profile.vision_angle * 0.5)):
		return false

	var dark_fraction: float = 1.0 if profile.rule_for(DEF_NpcTrait.Kind.DARK_PREDATOR) != null else profile.dark_vision_fraction
	if distance > maxf(profile.near_recognition_range, profile.vision_range * dark_fraction):
		var exposure: float = NpcLightingService.exposure_at(point, [observer.get_rid()])
		var sight_range: float = maxf(profile.near_recognition_range, profile.vision_range * lerpf(dark_fraction, 1.0, exposure))
		if distance > sight_range:
			return false

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, point, SIGHT_MASK, [observer.get_rid()])
	var hit: Dictionary = observer.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (target != null and HazardTargets.entity_for(hit.get("collider") as Node) == target)


#endregion

#region Слух
## Создаёт шум в реальной позиции тела без раскрытия личности слушателям.
static func action_noise(source: Entity, radius: float) -> void:
	var spatial: Node3D = source as Node as Node3D if is_instance_valid(source) else null
	if spatial != null and spatial.is_inside_tree():
		emit_noise(source, spatial.global_position, radius)

## Создаёт звуковое событие без раскрытия личности источника слушателям.
static func emit_noise(source: Entity, world_position: Vector3, radius: float, investigate: bool = true) -> void:
	var district: C_District = DistrictPopulationService.current()
	if district == null or not is_finite(radius) or radius <= 0.0:
		return

	var noise: NpcNoise = NpcNoise.new()
	noise.sequence = district.next_noise_sequence
	district.next_noise_sequence += 1
	noise.remaining = district.definition.decision_interval * 2.0
	noise.source = source
	noise.position = world_position
	noise.radius = radius
	noise.investigate = investigate
	district.noises.append(noise)

## Слышит место через ослабляющие препятствия без связи с невидимым источником.
static func hear(listener: Entity, profile: DEF_NpcProfile, noise: NpcNoise) -> bool:
	if noise.source == listener:
		return false

	var body: PhysicsBody3D = listener as Node as PhysicsBody3D
	if body == null or not body.is_inside_tree():
		return false

	var listener_position: Vector3 = body.global_position + Vector3.UP * EYE_HEIGHT
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(noise.position, listener_position, SIGHT_MASK)
	query.exclude = [body.get_rid()]
	var source_body: PhysicsBody3D = noise.source as Node as PhysicsBody3D if is_instance_valid(noise.source) else null
	if source_body != null:
		query.exclude.append(source_body.get_rid())
	var blocked: bool = not body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	var district: C_District = DistrictPopulationService.current()
	var radius: float = minf(profile.hearing_range, noise.radius) * (district.definition.hearing_wall_attenuation if blocked else 1.0)
	if listener_position.distance_to(noise.position) > radius:
		return false

	var awareness: C_NpcAwareness = listener.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.heard_position = noise.position
	awareness.heard_remaining = profile.search_seconds
	awareness.investigate_noise = noise.investigate
	return true

#endregion
