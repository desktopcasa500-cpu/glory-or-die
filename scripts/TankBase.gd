class_name TankBase
extends CharacterBody3D

signal module_damaged(module_name: String, health: float)
signal module_repaired(module_name: String)
signal tank_destroyed()
signal repair_started(module_name: String, duration: float)
signal repair_finished(module_name: String)
signal fired(projectile: Projectile)
signal status_changed()

@onready var engine: EngineComponent = $Components/Engine
@onready var ammo_rack: AmmoRackComponent = $Components/AmmoRack
@onready var turret_ring: TurretRingComponent = $Components/TurretRing
@onready var crew: CrewComponent = $Components/Crew
@onready var turret: Node3D = $Turret
@onready var turret_mesh: MeshInstance3D = $Turret/TurretMesh
@onready var muzzle: Marker3D = $Turret/Muzzle
@onready var repair_timer: Timer = $RepairTimer
@onready var hull_mesh: MeshInstance3D = $HullMesh
@onready var gun_barrel: MeshInstance3D = $Turret/Barrel

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
var bot_cooldown: float = 0.0

func _ready() -> void:
	set_meta("battle_target", true)
	GameState.projectile_impact.connect(_on_projectile_impact)
	engine.destroyed.connect(_on_engine_destroyed)
	engine.repaired.connect(_on_component_repaired)
	engine.fire_risk_changed.connect(_on_fire_risk_changed)
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
	destroyed = false
	repairing = false
	hull_health = 100.0
	reload_remaining = 0.0
	aim_remaining = 0.0
	bot_cooldown = 1.0
	_apply_visual_profile()

func _apply_visual_profile() -> void:
	var hull_scale: Vector3 = Vector3.ONE
	var turret_scale: Vector3 = Vector3.ONE
	var barrel_scale: Vector3 = Vector3.ONE
	var turret_visible: bool = true
	match tank_data.tank_name:
		"Churchill":
			hull_scale = Vector3(1.08, 1.15, 1.10)
			turret_scale = Vector3(0.98, 1.0, 0.98)
			barrel_scale = Vector3(0.92, 1.0, 0.92)
		"Hetzer":
			hull_scale = Vector3(0.88, 0.72, 0.96)
			turret_scale = Vector3(0.82, 0.72, 0.82)
			barrel_scale = Vector3(0.82, 0.82, 1.05)
			turret_visible = false
		"IS-2":
			hull_scale = Vector3(1.10, 1.04, 1.08)
			turret_scale = Vector3(1.04, 1.08, 1.04)
			barrel_scale = Vector3(1.30, 1.30, 1.30)
		"KV-1":
			hull_scale = Vector3(1.10, 1.08, 1.08)
			turret_scale = Vector3(1.08, 1.05, 1.08)
			barrel_scale = Vector3(1.05, 1.05, 1.08)
		"Panther":
			hull_scale = Vector3(1.02, 0.96, 1.06)
			turret_scale = Vector3(0.98, 0.92, 1.02)
			barrel_scale = Vector3(0.92, 0.92, 1.18)
		"Panzer IV":
			hull_scale = Vector3(0.96, 0.94, 1.00)
			turret_scale = Vector3(0.96, 0.96, 0.96)
			barrel_scale = Vector3(0.90, 0.90, 0.98)
		"Pershing":
			hull_scale = Vector3(1.04, 1.02, 1.04)
			turret_scale = Vector3(1.02, 1.02, 1.02)
			barrel_scale = Vector3(1.05, 1.05, 1.08)
		"Sherman":
			hull_scale = Vector3(1.00, 0.96, 1.00)
			turret_scale = Vector3(0.98, 1.00, 0.98)
			barrel_scale = Vector3(0.92, 0.92, 1.02)
		"StuG III":
			hull_scale = Vector3(0.92, 0.76, 1.00)
			turret_scale = Vector3(0.84, 0.68, 0.90)
			barrel_scale = Vector3(0.88, 0.88, 1.04)
			turret_visible = false
		"T-34":
			hull_scale = Vector3(0.98, 0.90, 1.04)
			turret_scale = Vector3(0.94, 0.90, 0.94)
			barrel_scale = Vector3(0.90, 0.90, 0.98)
		"Tiger":
			hull_scale = Vector3(1.10, 1.04, 1.08)
			turret_scale = Vector3(1.02, 1.02, 1.02)
			barrel_scale = Vector3(1.02, 1.02, 1.14)
		"Tiger II":
			hull_scale = Vector3(1.16, 1.12, 1.12)
			turret_scale = Vector3(1.08, 1.08, 1.08)
			barrel_scale = Vector3(1.06, 1.06, 1.20)
	hull_mesh.scale = hull_scale
	turret.scale = turret_scale
	gun_barrel.scale = barrel_scale
	turret.visible = turret_visible

func _exit_tree() -> void:
	if GameState.projectile_impact.is_connected(_on_projectile_impact):
		GameState.projectile_impact.disconnect(_on_projectile_impact)

func _physics_process(delta: float) -> void:
	if tank_data == null or destroyed:
		return
	_update_reload(delta)
	if repairing:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if is_player:
		_read_player_input()
		if Input.is_action_just_pressed("fire"):
			fire_cannon()
		if Input.is_action_pressed("repair"):
			start_repair()
	else:
		_update_bot(delta)
	_update_movement(delta)
	_update_turret(delta)

func _read_player_input() -> void:
	throttle_input = Input.get_axis("move_backward", "move_forward")
	steering_input = Input.get_axis("turn_left", "turn_right") * crew.steering_multiplier()
	turret_input = Input.get_axis("turret_left", "turret_right")

func _update_bot(delta: float) -> void:
	bot_cooldown = maxf(0.0, bot_cooldown - delta)
	var target: TankBase = GameState.player_tank
	if not is_instance_valid(target) or target.destroyed:
		throttle_input = 0.0
		turret_input = 0.0
		return
	var to_target: Vector3 = target.global_position - global_position
	var flat: Vector3 = Vector3(to_target.x, 0.0, to_target.z)
	var distance: float = flat.length()
	var forward: Vector3 = -global_transform.basis.z
	var cross_y: float = forward.cross(flat.normalized()).y if distance > 0.5 else 0.0
	turret_input = clampf(cross_y * 2.5, -1.0, 1.0)
	throttle_input = 0.6 if distance > 24.0 else (-0.25 if distance < 10.0 else 0.0)
	if distance < 65.0 and bot_cooldown <= 0.0 and absf(cross_y) < 0.12:
		fire_cannon()
		bot_cooldown = tank_data.reload_time_sec * 1.15 + 0.4

func _update_movement(delta: float) -> void:
	var target_speed_kmh: float = tank_data.top_speed_kmh if throttle_input >= 0.0 else tank_data.reverse_speed_kmh
	var target_speed_ms: float = target_speed_kmh / 3.6
	var forward: Vector3 = -global_transform.basis.z
	var desired_velocity: Vector3 = forward * throttle_input * target_speed_ms
	if not crew.can_accelerate() or not engine.operational:
		desired_velocity = Vector3.ZERO
	var response: float = 3.4 * tank_data.acceleration_factor * engine_factor()
	velocity = velocity.move_toward(desired_velocity, response * delta)
	var turn_rate: float = 0.78 * crew.steering_multiplier()
	if absf(throttle_input) > 0.05:
		rotate_y(steering_input * turn_rate * delta)
	move_and_slide()

func engine_factor() -> float:
	return 0.55 if engine.fire_risk else 1.0

func _update_turret(delta: float) -> void:
	if turret_ring.rotation_multiplier <= 0.0 or not turret.visible:
		return
	var rate: float = deg_to_rad(tank_data.turret_traverse_deg_sec) * turret_ring.rotation_multiplier
	turret.rotate_y(turret_input * rate * delta)

func _update_reload(delta: float) -> void:
	reload_remaining = maxf(0.0, reload_remaining - delta)
	aim_remaining = maxf(0.0, aim_remaining - delta)

func fire_cannon() -> void:
	if reload_remaining > 0.0 or aim_remaining > 0.0 or not ammo_rack.operational:
		return
	var projectile_scene: PackedScene = preload("res://scenes/Projectile.tscn")
	var projectile: Projectile = projectile_scene.instantiate() as Projectile
	get_tree().current_scene.add_child(projectile)
	var direction: Vector3 = -muzzle.global_transform.basis.z
	projectile.setup(muzzle.global_position, direction, tank_data, self)
	reload_remaining = tank_data.reload_time_sec * crew.reload_multiplier()
	aim_remaining = tank_data.aim_time_sec * crew.aim_multiplier()
	fired.emit(projectile)

func _on_projectile_impact(target: Node, hit_position: Vector3, hit_normal: Vector3, travel_direction: Vector3, penetration_mm: float, incidence_angle_deg: float) -> void:
	if target != self or destroyed:
		return
	var result: Dictionary = resolve_armor_hit(hit_position, hit_normal, travel_direction, penetration_mm, incidence_angle_deg)
	if bool(result["penetrated"]):
		apply_spall(hit_position, travel_direction, penetration_mm)
	status_changed.emit()

func resolve_armor_hit(hit_position: Vector3, hit_normal: Vector3, travel_direction: Vector3, projectile_penetration: float, incidence_angle: float) -> Dictionary:
	var local_hit: Vector3 = to_local(hit_position)
	var armor: float = tank_data.armor_side_mm
	if local_hit.z < -1.05:
		armor = tank_data.armor_front_mm
	elif local_hit.z > 1.05:
		armor = tank_data.armor_rear_mm
	var normal: Vector3 = hit_normal.normalized()
	var incoming: Vector3 = -travel_direction.normalized()
	var cosine: float = clampf(absf(normal.dot(incoming)), 0.08716, 1.0)
	var effective: float = armor / cosine
	var penetrated: bool = projectile_penetration >= effective
	if penetrated:
		var hull_damage: float = clampf(projectile_penetration / maxf(effective, 1.0) * 34.0, 4.0, 68.0)
		hull_health = maxf(0.0, hull_health - hull_damage)
		if hull_health <= 0.0:
			destroy_vehicle()
	else:
		module_damaged.emit("Armor", effective)
	status_changed.emit()
	return {"penetrated": penetrated, "effective_armor_mm": effective, "impact_angle_deg": incidence_angle}

func apply_spall(hit_position: Vector3, direction: Vector3, projectile_penetration: float) -> void:
	var local_hit: Vector3 = to_local(hit_position)
	var local_direction: Vector3 = (global_transform.basis.inverse() * direction.normalized()).normalized()
	var module_points: Array[Vector3] = [Vector3(0.0, 0.55, 0.7), Vector3(0.0, 0.8, -0.55), Vector3(0.0, 1.0, 0.0), Vector3(0.65, 1.05, 0.0)]
	var module_weights: Array[float] = [1.0, 1.0, 0.8, 0.55]
	for index: int in range(module_points.size()):
		var offset: Vector3 = module_points[index] - local_hit
		var distance_factor: float = 1.0 / maxf(0.75, offset.length())
		var cone_factor: float = maxf(0.0, local_direction.dot(offset.normalized()))
		var severity: float = projectile_penetration * cone_factor * distance_factor * module_weights[index]
		if severity < 20.0:
			continue
		match index:
			0:
				engine.apply_damage(severity)
			1:
				ammo_rack.apply_damage(severity, severity >= 72.0)
			2:
				turret_ring.apply_damage(severity, severity >= 80.0)
			3:
				if severity >= 55.0:
					crew.lose_member("gunner")
				elif severity >= 42.0:
					crew.lose_member("driver")
			module_damaged.emit(["Engine", "AmmoRack", "TurretRing", "Crew"][index], severity)
	status_changed.emit()

func start_repair() -> void:
	if repairing or destroyed:
		return
	var target: String = _find_repair_target()
	if target.is_empty():
		return
	repair_target = target
	repairing = true
	velocity = Vector3.ZERO
	var duration: float = 3.5 if target == "AmmoRack" else 3.0
	repair_timer.start(duration)
	repair_started.emit(target, duration)
	status_changed.emit()

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
	if not crew.commander_alive:
		return "Commander"
	return ""

func _on_repair_timer_timeout() -> void:
	repairing = false
	match repair_target:
		"Engine": engine.repair_basic()
		"AmmoRack": ammo_rack.repair_basic()
		"TurretRing": turret_ring.repair_basic()
		"Gunner": crew.repair_member("gunner")
		"Driver": crew.repair_member("driver")
		"Commander": crew.repair_member("commander")
	repair_finished.emit(repair_target)
	repair_target = ""
	status_changed.emit()

func _on_engine_destroyed(_component: EngineComponent) -> void:
	module_damaged.emit("Engine", 0.0)
	status_changed.emit()

func _on_ammo_rack_critical(_component: AmmoRackComponent) -> void:
	cook_off()

func _on_turret_ring_damaged(component: TurretRingComponent) -> void:
	module_damaged.emit("TurretRing", component.health)
	status_changed.emit()

func _on_component_repaired(component: Node) -> void:
	module_repaired.emit(component.name)
	status_changed.emit()

func _on_crew_member_lost(role: String) -> void:
	module_damaged.emit(role, 0.0)
	status_changed.emit()

func _on_crew_member_repaired(role: String) -> void:
	module_repaired.emit(role)
	status_changed.emit()

func _on_fire_risk_changed(_active: bool) -> void:
	status_changed.emit()

func cook_off() -> void:
	if destroyed:
		return
	destroyed = true
	repairing = false
	repair_timer.stop()
	velocity = Vector3.ZERO
	set_physics_process(false)
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)
	var turret_body: RigidBody3D = RigidBody3D.new()
	turret_body.name = "EjectedTurret"
	turret_body.global_transform = turret_mesh.global_transform
	turret_body.mass = maxf(1.0, tank_data.mass_tons * 0.08)
	turret_body.collision_layer = 0
	turret_body.collision_mask = 0
	get_tree().current_scene.add_child(turret_body)
	var mesh_copy: MeshInstance3D = MeshInstance3D.new()
	mesh_copy.mesh = turret_mesh.mesh
	mesh_copy.material_override = turret_mesh.material_override
	turret_body.add_child(mesh_copy)
	turret_mesh.visible = false
	turret_body.apply_central_impulse(Vector3.UP * (6.0 + tank_data.mass_tons * 0.03) - global_transform.basis.z * 2.0)
	_spawn_cookoff_particles()
	tank_destroyed.emit()
	status_changed.emit()

func _spawn_cookoff_particles() -> void:
	var fire: GPUParticles3D = GPUParticles3D.new()
	fire.name = "CookoffFire"
	fire.amount = 20
	fire.lifetime = 1.8
	fire.one_shot = true
	var fire_process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	fire_process.direction = Vector3.UP
	fire_process.spread = 28.0
	fire_process.initial_velocity_min = 1.2
	fire_process.initial_velocity_max = 3.2
	fire_process.scale_min = 0.12
	fire_process.scale_max = 0.28
	fire_process.gravity = Vector3(0.0, 0.3, 0.0)
	fire.process_material = fire_process
	var fire_quad: QuadMesh = QuadMesh.new()
	fire_quad.size = Vector2(0.5, 0.5)
	var fire_mat: StandardMaterial3D = StandardMaterial3D.new()
	fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_mat.albedo_color = Color(1.0, 0.42, 0.05, 0.82)
	fire_quad.material = fire_mat
	fire.draw_pass_1 = fire_quad
	add_child(fire)
	fire.restart()
	var smoke: GPUParticles3D = GPUParticles3D.new()
	smoke.name = "CookoffSmoke"
	smoke.amount = 28
	smoke.lifetime = 3.6
	smoke.one_shot = true
	var smoke_process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	smoke_process.direction = Vector3.UP
	smoke_process.spread = 35.0
	smoke_process.initial_velocity_min = 0.6
	smoke_process.initial_velocity_max = 1.8
	smoke_process.scale_min = 0.18
	smoke_process.scale_max = 0.42
	smoke_process.gravity = Vector3(0.0, -0.05, 0.0)
	smoke.process_material = smoke_process
	var smoke_quad: QuadMesh = QuadMesh.new()
	smoke_quad.size = Vector2(0.8, 0.8)
	var smoke_mat: StandardMaterial3D = StandardMaterial3D.new()
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.albedo_color = Color(0.18, 0.18, 0.18, 0.55)
	smoke_quad.material = smoke_mat
	smoke.draw_pass_1 = smoke_quad
	add_child(smoke)
	smoke.restart()

func destroy_vehicle() -> void:
	if destroyed:
		return
	if ammo_rack.health <= 0.0:
		cook_off()
		return
	destroyed = true
	set_physics_process(false)
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)
	tank_destroyed.emit()
	status_changed.emit()
