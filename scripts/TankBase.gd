class_name TankBase
extends CharacterBody3D

signal module_damaged(module_name: String, health: float)
signal tank_destroyed()
signal repair_started(module_name: String, duration: float)
signal repair_finished(module_name: String)
signal fired(projectile: Node3D)

@onready var engine: EngineComponent = $Components/Engine
@onready var ammo_rack: AmmoRackComponent = $Components/AmmoRack
@onready var turret_ring: TurretRingComponent = $Components/TurretRing
@onready var crew: CrewComponent = $Components/Crew
@onready var turret: Node3D = $Turret
@onready var turret_mesh: MeshInstance3D = $Turret/TurretMesh
@onready var repair_timer: Timer = $RepairTimer

var tank_data: TankData
var is_player: bool = false
var destroyed: bool = false
var repairing: bool = false
var repair_target: String = ""
var hull_health: float = 100.0
var reload_remaining: float = 0.0
var aim_remaining: float = 0.0
var steering_input: float = 0.0
var throttle_input: float = 0.0
var turret_input: float = 0.0

func _ready() -> void:
	engine.destroyed.connect(_on_engine_destroyed)
	engine.repaired.connect(_on_component_repaired)
	ammo_rack.critical_hit.connect(_on_ammo_rack_critical)
	ammo_rack.repaired.connect(_on_component_repaired)
	turret_ring.damaged.connect(_on_turret_ring_damaged)
	turret_ring.repaired.connect(_on_component_repaired)
	crew.crew_member_lost.connect(_on_crew_member_lost)
	crew.crew_member_repaired.connect(_on_crew_member_repaired)
	repair_timer.timeout.connect(_on_repair_timer_timeout)

func configure(data: TankData, player_controlled: bool) -> void:
	tank_data = data
	is_player = player_controlled
	hull_health = 100.0
	reload_remaining = 0.0
	aim_remaining = 0.0
	destroyed = false

func _physics_process(delta: float) -> void:
	if tank_data == null or destroyed:
		return
	if repairing:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if is_player:
		_read_player_input()
	_update_movement(delta)
	_update_turret(delta)
	_update_reload(delta)
	if is_player and Input.is_action_just_pressed("fire"):
		fire_cannon()
	if is_player and Input.is_action_pressed("repair") and not repairing:
		start_repair()

func _read_player_input() -> void:
	throttle_input = Input.get_axis("move_backward", "move_forward")
	steering_input = Input.get_axis("turn_left", "turn_right") * crew.steering_multiplier()
	turret_input = Input.get_axis("turret_left", "turret_right")

func _update_movement(delta: float) -> void:
	var target_speed_kmh: float = tank_data.top_speed_kmh if throttle_input >= 0.0 else tank_data.reverse_speed_kmh
	var target_speed_ms: float = target_speed_kmh / 3.6
	var forward: Vector3 = -global_transform.basis.z
	var desired_velocity: Vector3 = forward * throttle_input * target_speed_ms
	if not crew.can_accelerate() or not engine.operational:
		desired_velocity = Vector3.ZERO
	var response: float = 3.0 * tank_data.acceleration_factor
	velocity = velocity.move_toward(desired_velocity, response * delta)
	var turn_rate: float = 0.75 * crew.steering_multiplier()
	if absf(throttle_input) > 0.05:
		rotate_y(steering_input * turn_rate * delta)
	move_and_slide()

func _update_turret(delta: float) -> void:
	var multiplier: float = turret_ring.rotation_multiplier
	if multiplier <= 0.0:
		return
	var rate: float = deg_to_rad(tank_data.turret_traverse_deg_sec) * multiplier
	turret.rotate_y(turret_input * rate * delta)

func _update_reload(delta: float) -> void:
	if reload_remaining > 0.0:
		reload_remaining = maxf(0.0, reload_remaining - delta)
	if aim_remaining > 0.0:
		aim_remaining = maxf(0.0, aim_remaining - delta)

func fire_cannon() -> void:
	if reload_remaining > 0.0 or aim_remaining > 0.0 or not ammo_rack.operational:
		return
	var muzzle: Node3D = $Turret/Muzzle
	var projectile_scene: PackedScene = load("res://scenes/Projectile.tscn") as PackedScene
	var projectile: Projectile = projectile_scene.instantiate() as Projectile
	get_tree().current_scene.add_child(projectile)
	var direction: Vector3 = -muzzle.global_transform.basis.z
	projectile.setup(muzzle.global_position, direction, tank_data.muzzle_velocity_ms, tank_data.penetration_100m_mm, self)
	reload_remaining = tank_data.reload_time_sec * crew.reload_multiplier()
	aim_remaining = tank_data.aim_time_sec * crew.aim_multiplier()
	fired.emit(projectile)

func resolve_armor_hit(hit_position: Vector3, hit_normal: Vector3, travel_direction: Vector3, projectile_penetration: float, incidence_angle: float) -> Dictionary:
	var local_hit: Vector3 = to_local(hit_position)
	var armor: float = tank_data.armor_side_mm
	if local_hit.z < -0.9:
		armor = tank_data.armor_front_mm
	elif local_hit.z > 0.9:
		armor = tank_data.armor_rear_mm
	elif absf(local_hit.x) > 0.9:
		armor = tank_data.armor_side_mm
	var cosine: float = maxf(absf(hit_normal.normalized().dot(-travel_direction.normalized())), 0.0872)
	var effective: float = armor / cosine
	var penetrated: bool = projectile_penetration >= effective
	if penetrated:
		hull_health = maxf(0.0, hull_health - clampf(projectile_penetration / maxf(effective, 1.0) * 35.0, 5.0, 70.0))
		if hull_health <= 0.0:
			destroy_vehicle()
	return {"penetrated": penetrated, "effective_armor_mm": effective, "impact_angle_deg": incidence_angle, "spall_direction": travel_direction}

func apply_spall(hit_position: Vector3, direction: Vector3, projectile_penetration: float) -> void:
	var local: Vector3 = to_local(hit_position)
	var candidates: Array[Dictionary] = [
		{"node": engine, "point": Vector3(0.0, 0.4, 0.7), "weight": 1.0},
		{"node": ammo_rack, "point": Vector3(0.0, 0.9, -0.5), "weight": 0.8},
		{"node": turret_ring, "point": Vector3(0.0, 1.2, 0.0), "weight": 0.7}
	]
	for item: Dictionary in candidates:
		var module: Node = item["node"] as Node
		var module_point: Vector3 = item["point"] as Vector3
		var cone_factor: float = maxf(0.0, direction.normalized().dot((module_point - local).normalized()))
		var chance: float = clampf(cone_factor * float(item["weight"]), 0.0, 1.0)
		if chance > 0.28:
			if module == ammo_rack:
				ammo_rack.apply_damage(projectile_penetration * chance, projectile_penetration > 120.0)
			elif module == engine:
				engine.apply_damage(projectile_penetration * chance)
			elif module == turret_ring:
				turret_ring.apply_damage(projectile_penetration * chance, projectile_penetration > 150.0)
		module_damaged.emit(module.name, projectile_penetration * chance)
	var crew_hits: float = clampf(projectile_penetration * 0.25, 0.0, 100.0)
	if crew_hits > 30.0:
		crew.lose_member("gunner")

func start_repair() -> void:
	if repairing or destroyed:
		return
	var target: String = _find_repair_target()
	if target.is_empty():
		return
	repair_target = target
	repairing = true
	velocity = Vector3.ZERO
	var duration: float = 3.0
	repair_timer.start(duration)
	repair_started.emit(target, duration)

func _find_repair_target() -> String:
	if not engine.operational:
		return "Engine"
	if not ammo_rack.operational:
		return "AmmoRack"
	if not turret_ring.operational:
		return "TurretRing"
	if not crew.gunner_alive:
		return "Gunner"
	if not crew.driver_alive:
		return "Driver"
	return ""

func _on_repair_timer_timeout() -> void:
	repairing = false
	match repair_target:
		"Engine": engine.repair_basic()
		"AmmoRack": ammo_rack.repair_basic()
		"TurretRing": turret_ring.repair_basic()
		"Gunner": crew.repair_member("gunner")
		"Driver": crew.repair_member("driver")
	repair_finished.emit(repair_target)
	repair_target = ""

func _on_engine_destroyed(_component: EngineComponent) -> void:
	module_damaged.emit("Engine", 100.0)

func _on_ammo_rack_critical(_component: AmmoRackComponent) -> void:
	cook_off()

func _on_turret_ring_damaged(_component: TurretRingComponent) -> void:
	module_damaged.emit("TurretRing", turret_ring.health)

func _on_component_repaired(component: Node) -> void:
	repair_finished.emit(component.name)

func _on_crew_member_lost(role: String) -> void:
	module_damaged.emit(role, 100.0)

func _on_crew_member_repaired(role: String) -> void:
	repair_finished.emit(role)

func cook_off() -> void:
	if destroyed:
		return
	destroyed = true
	velocity = Vector3.ZERO
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	var turret_body: RigidBody3D = RigidBody3D.new()
	turret_body.name = "EjectedTurret"
	turret_body.global_transform = turret_mesh.global_transform
	get_tree().current_scene.add_child(turret_body)
	var mesh_copy: MeshInstance3D = MeshInstance3D.new()
	mesh_copy.mesh = turret_mesh.mesh
	mesh_copy.material_override = turret_mesh.material_override
	turret_body.add_child(mesh_copy)
	turret_mesh.visible = false
	turret_body.apply_central_impulse(Vector3.UP * 7.5 + -global_transform.basis.z * 2.0)
	var smoke: GPUParticles3D = GPUParticles3D.new()
	smoke.amount = 32
	smoke.lifetime = 2.5
	smoke.one_shot = true
	add_child(smoke)
	tank_destroyed.emit()

func destroy_vehicle() -> void:
	if destroyed:
		return
	destroyed = true
	velocity = Vector3.ZERO
	set_collision_layer_value(1, false)
	tank_destroyed.emit()
