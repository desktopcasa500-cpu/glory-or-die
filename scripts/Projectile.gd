class_name Projectile
extends Node3D

signal impact_registered(position: Vector3, normal: Vector3, angle_deg: float, penetrated: bool)
signal ricochet(position: Vector3, normal: Vector3)

const AIR_DENSITY: float = 1.225
const GRAVITY: Vector3 = Vector3(0.0, -9.80665, 0.0)
const MIN_SPEED_MS: float = 45.0
const MAX_LIFETIME_SEC: float = 8.0
const TICK_STEP_SEC: float = 1.0 / 120.0

var velocity_vector: Vector3 = Vector3.ZERO
var projectile_mass_kg: float = 8.0
var projectile_diameter_m: float = 0.08
var drag_coefficient: float = 0.30
var penetration_100m_mm: float = 100.0
var shooter: Node3D
var lifetime: float = 0.0
var active: bool = false
var ricochet_count: int = 0

func setup(start_position: Vector3, direction: Vector3, data: TankData, owner_node: Node3D) -> void:
	global_position = start_position
	velocity_vector = direction.normalized() * data.muzzle_velocity_ms
	projectile_mass_kg = maxf(0.1, data.projectile_mass_kg)
	projectile_diameter_m = maxf(0.01, data.projectile_diameter_m)
	drag_coefficient = clampf(data.projectile_drag_coefficient, 0.05, 0.8)
	penetration_100m_mm = data.penetration_100m_mm
	shooter = owner_node
	lifetime = 0.0
	ricochet_count = 0
	active = true

func _ready() -> void:
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if not active:
		return
	lifetime += delta
	if lifetime >= MAX_LIFETIME_SEC or velocity_vector.length() < MIN_SPEED_MS:
		active = false
		queue_free()
		return
	var remaining: float = delta
	while remaining > 0.0 and active:
		var step: float = minf(TICK_STEP_SEC, remaining)
		_step_simulation(step)
		remaining -= step

func _step_simulation(delta: float) -> void:
	var previous_position: Vector3 = global_position
	var speed: float = velocity_vector.length()
	var area: float = PI * pow(projectile_diameter_m * 0.5, 2.0)
	var drag_force: float = 0.5 * AIR_DENSITY * speed * speed * drag_coefficient * area
	var drag_accel: Vector3 = Vector3.ZERO
	if speed > 0.01:
		drag_accel = -velocity_vector.normalized() * (drag_force / projectile_mass_kg)
	velocity_vector += (GRAVITY + drag_accel) * delta
	var next_position: Vector3 = previous_position + velocity_vector * delta
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(previous_position, next_position)
	query.collision_mask = 1 | 2
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if is_instance_valid(shooter):
		query.exclude = [shooter.get_rid()]
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty():
		_handle_impact(hit, previous_position, next_position)
		return
	global_position = next_position
	if speed > 0.01:
		look_at(global_position + velocity_vector.normalized(), Vector3.UP)

func _handle_impact(hit: Dictionary, previous_position: Vector3, next_position: Vector3) -> void:
	var hit_position: Vector3 = hit["position"] as Vector3
	var hit_normal: Vector3 = hit["normal"] as Vector3
	var travel: Vector3 = (next_position - previous_position).normalized()
	var incoming: Vector3 = -travel
	var cosine: float = clampf(absf(hit_normal.normalized().dot(incoming)), 0.0, 1.0)
	var angle_deg: float = rad_to_deg(acos(cosine))
	if angle_deg > 70.0:
		_ricochet(hit_position, hit_normal)
		return
	var collider: Node = hit.get("collider", null) as Node
	if is_instance_valid(collider) and collider.get_meta("battle_target", false):
		GameState.projectile_impact.emit(collider, hit_position, hit_normal, travel, penetration_100m_mm, angle_deg)
	impact_registered.emit(hit_position, hit_normal, angle_deg, false)
	active = false
	queue_free()

func _ricochet(position: Vector3, normal: Vector3) -> void:
	if ricochet_count >= 3:
		active = false
		queue_free()
		return
	ricochet_count += 1
	ricochet.emit(position, normal)
	velocity_vector = velocity_vector.bounce(normal).normalized() * velocity_vector.length() * 0.62
	global_position = position + normal * 0.015
