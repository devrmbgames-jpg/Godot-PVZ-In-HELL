extends RefCounted
## Physical multi-point sight and bounded audible stimuli; no omniscient target tracking.
class_name NpcPerceptionService

const EYE_HEIGHT: float = 1.5
const TORSO_HEIGHT: float = 0.9
const SHOULDER_OFFSET: float = 0.22
const SIGHT_MASK: int = 31

#region Sight
## Checks physical visibility against authored eyes, light and partial cover.
static func can_see(observer: Entity, target: Entity, profile: DEF_NpcProfile, allow_dead_target: bool = false) -> bool:
	var target_available: bool = is_instance_valid(target) and is_instance_valid(ECS.world) and ECS.world.entities.has(target) if allow_dead_target else GrabService.holder_available(target)
	if observer == target or not target_available or not GrabService.holder_available(observer):
		return false
	var observer_body: PhysicsBody3D = observer as Node as PhysicsBody3D
	var target_body: PhysicsBody3D = target as Node as PhysicsBody3D
	if observer_body == null or target_body == null or not observer_body.is_inside_tree() or not target_body.is_inside_tree():
		return false
	var eye: Vector3 = observer_body.global_position + Vector3.UP * EYE_HEIGHT
	var torso: Vector3 = target_body.global_position + Vector3.UP * TORSO_HEIGHT
	var target_offset: Vector3 = torso - eye
	var distance: float = target_offset.length()
	var exposure: float = NpcLightingService.exposure_at(torso, [target_body.get_rid()])
	var dark_fraction: float = 1.0 if profile.rule_for(DEF_NpcTrait.Kind.DARK_PREDATOR) != null else profile.dark_vision_fraction
	var sight_range: float = maxf(profile.near_recognition_range, profile.vision_range * lerpf(dark_fraction, 1.0, exposure))
	if distance > sight_range:
		return false
	var head: Node3D = observer_body.get_node_or_null("HeadY") as Node3D
	var forward: Vector3 = -(head.global_basis.z if head != null else observer_body.global_basis.z).normalized()
	if distance > profile.near_recognition_range and forward.dot(target_offset.normalized()) < cos(deg_to_rad(profile.vision_angle * 0.5)):
		return false
	var shoulder: Vector3 = target_body.global_basis.x.normalized() * SHOULDER_OFFSET
	var points: Array[Vector3] = [target_body.global_position + Vector3.UP * EYE_HEIGHT, torso, torso + shoulder, torso - shoulder]
	for point: Vector3 in points:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, point, SIGHT_MASK)
		query.exclude = [observer_body.get_rid()]
		var hit: Dictionary = observer_body.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.get("collider") == target_body:
			return true
	return false

## Updates only confirmed positions; hidden positions are not copied from the live target.
static func sense(actor: E_DistrictNpc, person: NpcRecord, player: Entity, delta: float) -> void:
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.player_visible = player != null and can_see(actor, player, person.profile)
	if not awareness.player_visible and NpcDialogueService.participant(actor) == null:
		NpcIntentService.look_along_movement(actor)
	var opponent: Entity = CombatService.target_for(actor)
	awareness.target_visible = opponent != null and can_see(actor, opponent, person.profile)
	if awareness.target_visible:
		awareness.last_seen_position = (opponent as Node as Node3D).global_position
		awareness.has_last_seen = true
		awareness.search_elapsed = 0.0
		awareness.search_index = 0
	elif opponent != null:
		awareness.search_elapsed += delta
	awareness.heard_remaining = maxf(0.0, awareness.heard_remaining - delta)
	var district: C_District = DistrictPopulationService.current()
	for noise: NpcNoise in district.noises:
		if noise.sequence > awareness.last_noise_sequence:
			awareness.last_noise_sequence = noise.sequence
			hear(actor, person.profile, noise)
#endregion

#region Hearing
## Emits a spatial action using the body's actual position without identifying it to listeners.
static func action_noise(source: Entity, radius: float) -> void:
	var spatial: Node3D = source as Node as Node3D if is_instance_valid(source) else null
	if spatial != null and spatial.is_inside_tree():
		emit_noise(source, spatial.global_position, radius)

## Emits a stimulus without revealing actor identity to listeners.
static func emit_noise(source: Entity, world_position: Vector3, radius: float) -> void:
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
	district.noises.append(noise)

## Hears a location through attenuating obstacles without binding an unseen source.
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
	return true

## Produces footsteps from actual body motion at the decision cadence.
static func footsteps(actor: Entity, delta: float) -> void:
	var body: RigidBody3D = actor as Node as RigidBody3D
	if body == null or not actor.enabled:
		return
	var speed: float = Vector2(body.linear_velocity.x, body.linear_velocity.z).length()
	if speed < 0.2:
		return
	var district: C_District = DistrictPopulationService.current()
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	var elapsed: float = awareness.footstep_elapsed + delta if awareness != null else district.player_step_elapsed + delta
	if elapsed < district.definition.footstep_interval:
		if awareness != null: awareness.footstep_elapsed = elapsed
		else: district.player_step_elapsed = elapsed
		return
	if awareness != null: awareness.footstep_elapsed = 0.0
	else: district.player_step_elapsed = 0.0
	var crouch: C_Crouch = actor.get_component(C_Crouch) as C_Crouch
	var radius: float = district.definition.running_noise_radius if speed > 3.0 else district.definition.walking_noise_radius
	if crouch != null and crouch.active:
		radius *= district.definition.crouching_noise_fraction
	emit_noise(actor, body.global_position + Vector3.UP * TORSO_HEIGHT, radius)
#endregion
