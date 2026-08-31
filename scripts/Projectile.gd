class_name Projectile
extends Node3D

signal impact(position: Vector3, result: Dictionary)
signal ricochet(position: Vector3, direction: Vector3)

@export var drag_coefficient: float = 0.32
@export var projectile_diameter_mm: float = 75.0
@export var projectile_mass_kg: float = 6.8
@export var gravity: float = 9.80665
@export var air_density: float = 1.225
@export var max_lifetime_sec: float = 20.0

var velocity: Vector3 = Vector3.ZERO
var penetration_mm: float = 0.0
var shooter: Node = null
var lifetime: float = 0.0
var active: bool = true

func setup(origin: Vector3, direction: Vector3, muzzle_velocity: float, penetration: float, source: Node = null) -> void:
	global_position = origin
	velocity = direction.normalized() * muzzle_velocity
	penetration_mm = penetration
	shooter = source

func _physics_process(delta: float) -> void:
	if not active:
		return
	lifetime += delta
	if lifetime >= max_lifetime_sec:
		active = false
		queue_free()
		return
	var old_position: Vector3 = global_position
	var speed: float = velocity.length()
	if speed > 0.01:
		var area_m2: float = PI * pow(projectile_diameter_mm * 0.001 * 0.5, 2.0)
		var drag_force: float = 0.5 * air_density * speed * speed * drag_coefficient * area_m2
		var acceleration: Vector3 = -velocity.normalized() * (drag_force / maxf(projectile_mass_kg, 0.001))
		velocity += (acceleration + Vector3.DOWN * gravity) * delta
	global_position += velocity * delta
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(old_position, global_position)
	query.exclude = [self, shooter]
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty():
		_process_impact(hit)

func _process_impact(hit: Dictionary) -> void:
	active = false
	var collider: Object = hit.get("collider") as Object
	var position: Vector3 = hit.get("position", global_position) as Vector3
	var normal: Vector3 = hit.get("normal", Vector3.UP) as Vector3
	var travel_direction: Vector3 = velocity.normalized()
	var incidence: float = rad_to_deg(acos(clampf(absf((-travel_direction).dot(normal)), 0.0, 1.0)))
	var ricochet_angle: float = 70.0
	var result: Dictionary = {"penetrated": false, "effective_armor_mm": 0.0, "impact_angle_deg": incidence, "spall_direction": travel_direction}
	if collider != null and collider.has_method("resolve_armor_hit"):
		result = collider.call("resolve_armor_hit", position, normal, travel_direction, penetration_mm, incidence) as Dictionary
	if incidence > ricochet_angle or not bool(result.get("penetrated", false)):
		if incidence > ricochet_angle:
			ricochet.emit(position, velocity.bounce(normal).normalized())
		else:
			impact.emit(position, result)
		queue_free()
		return
	if collider != null and collider.has_method("apply_spall"):
		collider.call("apply_spall", position, travel_direction, penetration_mm)
	impact.emit(position, result)
	queue_free()
