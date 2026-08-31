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
var target_tank: TankBase

func _ready() -> void:
    set_meta("battle_target", true)
    if not GameState.projectile_impact.is_connected(_on_projectile_impact):
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
    repair_target = ""
    hull_health = data.hull_health
    reload_remaining = 0.0
    aim_remaining = 0.0
    bot_cooldown = 1.0
    target_tank = null
    engine.reset_state()
    ammo_rack.reset_state()
    turret_ring.reset_state()
    crew.reset_state()
    _apply_visual_profile()
    set_physics_process(true)
    set_collision_layer_value(2, true)
    set_collision_mask_value(1, true)
    status_changed.emit()

func _apply_visual_profile() -> void:
    if tank_data == null:
        return
    var profile: Dictionary = GameState.get_visual_profile(tank_data.tank_name)
    hull_mesh.scale = profile.get("hull_scale", Vector3.ONE)
    turret.scale = profile.get("turret_scale", Vector3.ONE)
    gun_barrel.scale = profile.get("barrel_scale", Vector3.ONE)
    turret.visible = profile.get("turret_visible", true)
    hull_mesh.mesh = GameState.build_hull_mesh(profile)
    turret_mesh.mesh = GameState.build_turret_mesh(profile)
    gun_barrel.mesh = GameState.build_barrel_mesh(profile)

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
    target_tank = GameState.find_nearest_enemy(self)
    if not is_instance_valid(target_tank) or target_tank.destroyed:
        throttle_input = 0.0
        steering_input = 0.0
        turret_input = 0.0
        return
    var to_target: Vector3 = target_tank.global_position - global_position
    var flat_target: Vector3 = Vector3(to_target.x, 0.0, to_target.z)
    var distance: float = flat_target.length()
    if distance <= 0.5:
        throttle_input = 0.0
        steering_input = 0.0
        turret_input = 0.0
        return
    var flat_direction: Vector3 = flat_target.normalized()
    var forward: Vector3 = -global_transform.basis.z
    var cross_value: float = forward.cross(flat_direction).y
    steering_input = clampf(cross_value * 1.35, -1.0, 1.0)
    turret_input = clampf(cross_value * 2.2, -1.0, 1.0)
    if distance > 34.0:
        throttle_input = 0.75
    elif distance < 13.0:
        throttle_input = -0.30
    else:
        throttle_input = 0.05
    if distance < tank_data.bot_fire_range and absf(cross_value) < tank_data.bot_fire_alignment and bot_cooldown <= 0.0:
        fire_cannon()
        bot_cooldown = maxf(0.5, tank_data.reload_time_sec * 0.92)

func _update_movement(delta: float) -> void:
    var speed_kmh: float = tank_data.top_speed_kmh
    if throttle_input < 0.0:
        speed_kmh = tank_data.reverse_speed_kmh
    var target_speed_ms: float = speed_kmh / 3.6
    var forward: Vector3 = -global_transform.basis.z
    var desired_velocity: Vector3 = forward * throttle_input * target_speed_ms
    if not crew.can_accelerate() or not engine.operational:
        desired_velocity = Vector3.ZERO
    var response: float = 2.8 * tank_data.acceleration_factor * engine_factor()
    velocity = velocity.move_toward(desired_velocity, response * delta)
    var turn_rate: float = deg_to_rad(tank_data.hull_turn_deg_sec) * crew.steering_multiplier()
    if absf(throttle_input) > 0.05:
        rotate_y(steering_input * turn_rate * delta)
    move_and_slide()

func engine_factor() -> float:
    if engine.fire_risk:
        return 0.55
    return 1.0

func _update_turret(delta: float) -> void:
    if not turret.visible or turret_ring.rotation_multiplier <= 0.0:
        return
    var rate: float = deg_to_rad(tank_data.turret_traverse_deg_sec) * turret_ring.rotation_multiplier
    turret.rotate_y(turret_input * rate * delta)

func _update_reload(delta: float) -> void:
    reload_remaining = maxf(0.0, reload_remaining - delta)
    aim_remaining = maxf(0.0, aim_remaining - delta)

func fire_cannon() -> void:
    if tank_data == null or destroyed or repairing:
        return
    if reload_remaining > 0.0 or aim_remaining > 0.0 or not ammo_rack.operational:
        return
    var projectile_scene: PackedScene = preload("res://scenes/Projectile.tscn")
    var projectile: Projectile = projectile_scene.instantiate() as Projectile
    if projectile == null:
        return
    get_tree().current_scene.add_child(projectile)
    var direction: Vector3 = -muzzle.global_transform.basis.z
    projectile.setup(muzzle.global_position, direction, tank_data, self)
    reload_remaining = tank_data.reload_time_sec * crew.reload_multiplier()
    aim_remaining = tank_data.aim_time_sec * crew.aim_multiplier()
    fired.emit(projectile)
    status_changed.emit()

func _on_projectile_impact(target: Node, hit_position: Vector3, hit_normal: Vector3, travel_direction: Vector3, penetration_mm: float, incidence_angle_deg: float) -> void:
    if destroyed or target != self:
        return
    var result: Dictionary = resolve_armor_hit(hit_position, hit_normal, travel_direction, penetration_mm, incidence_angle_deg)
    if bool(result.get("penetrated", false)):
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
    var effective_armor: float = armor / cosine
    var penetrated: bool = projectile_penetration >= effective_armor
    var hull_damage: float = 0.0
    if penetrated:
        hull_damage = clampf((projectile_penetration / maxf(effective_armor, 1.0)) * tank_data.impact_damage_factor, 8.0, tank_data.max_hull_damage)
        hull_health = maxf(0.0, hull_health - hull_damage)
        module_damaged.emit("Hull", hull_health)
        if hull_health <= 0.0:
            destroy_vehicle()
    return {"penetrated": penetrated, "effective_armor_mm": effective_armor, "impact_angle_deg": incidence_angle, "hull_damage": hull_damage}

func apply_spall(hit_position: Vector3, direction: Vector3, projectile_penetration: float) -> void:
    var local_hit: Vector3 = to_local(hit_position)
    var local_direction: Vector3 = (global_transform.basis.inverse() * direction.normalized()).normalized()
    var module_points: Array[Vector3] = [Vector3(0.0, 0.55, 0.70), Vector3(0.0, 0.82, -0.55), Vector3(0.0, 1.02, 0.0), Vector3(0.62, 1.04, 0.08), Vector3(-0.60, 1.00, 0.08)]
    var module_weights: Array[float] = [1.0, 1.0, 0.82, 0.58, 0.48]
    for index: int in range(module_points.size()):
        var offset: Vector3 = module_points[index] - local_hit
        var offset_length: float = offset.length()
        if offset_length <= 0.001:
            continue
        var cone_factor: float = maxf(0.0, local_direction.dot(offset.normalized()))
        var distance_factor: float = 1.0 / maxf(0.75, offset_length)
        var severity: float = projectile_penetration * cone_factor * distance_factor * module_weights[index]
        if severity < 18.0:
            continue
        if index == 0:
            engine.apply_damage(severity)
            module_damaged.emit("Engine", engine.health)
        elif index == 1:
            ammo_rack.apply_damage(severity, severity >= tank_data.ammo_cookoff_threshold)
            module_damaged.emit("AmmoRack", ammo_rack.health)
        elif index == 2:
            turret_ring.apply_damage(severity, severity >= tank_data.turret_ring_lock_threshold)
            module_damaged.emit("TurretRing", turret_ring.health)
        elif index == 3:
            if severity >= tank_data.crew_knockout_threshold:
                crew.lose_member("gunner")
                module_damaged.emit("Gunner", 0.0)
        else:
            if severity >= tank_data.crew_knockout_threshold:
                crew.lose_member("driver")
                module_damaged.emit("Driver", 0.0)
    status_changed.emit()

func start_repair() -> void:
    if destroyed or repairing:
        return
    var target: String = _find_repair_target()
    if target.is_empty():
        return
    repair_target = target
    repairing = true
    velocity = Vector3.ZERO
    var duration: float = 3.0
    if target == "AmmoRack":
        duration = 4.0
    elif target == "TurretRing":
        duration = 3.5
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
    if not crew.loader_alive:
        return "Loader"
    return ""

func _on_repair_timer_timeout() -> void:
    repairing = false
    if repair_target == "Engine":
        engine.repair_basic()
    elif repair_target == "AmmoRack":
        ammo_rack.repair_basic()
    elif repair_target == "TurretRing":
        turret_ring.repair_basic()
    elif repair_target == "Gunner":
        crew.repair_member("gunner")
    elif repair_target == "Driver":
        crew.repair_member("driver")
    elif repair_target == "Commander":
        crew.repair_member("commander")
    elif repair_target == "Loader":
        crew.repair_member("loader")
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
    turret.visible = false
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
    turret_body.apply_central_impulse(Vector3.UP * (6.0 + tank_data.mass_tons * 0.03) - global_transform.basis.z * 2.0)
    _spawn_cookoff_particles()
    tank_destroyed.emit()
    status_changed.emit()

func _spawn_cookoff_particles() -> void:
    var fire: GPUParticles3D = GPUParticles3D.new()
    fire.name = "CookoffFire"
    fire.amount = 18
    fire.lifetime = 1.6
    fire.one_shot = true
    var fire_process: ParticleProcessMaterial = ParticleProcessMaterial.new()
    fire_process.direction = Vector3.UP
    fire_process.spread = 30.0
    fire_process.initial_velocity_min = 1.0
    fire_process.initial_velocity_max = 3.0
    fire_process.scale_min = 0.10
    fire_process.scale_max = 0.30
    fire_process.gravity = Vector3(0.0, 0.25, 0.0)
    fire.process_material = fire_process
    var fire_quad: QuadMesh = QuadMesh.new()
    fire_quad.size = Vector2(0.45, 0.45)
    var fire_material: StandardMaterial3D = StandardMaterial3D.new()
    fire_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    fire_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    fire_material.albedo_color = Color(1.0, 0.35, 0.04, 0.84)
    fire_quad.material = fire_material
    fire.draw_pass_1 = fire_quad
    add_child(fire)
    fire.restart()
    var smoke: GPUParticles3D = GPUParticles3D.new()
    smoke.name = "CookoffSmoke"
    smoke.amount = 24
    smoke.lifetime = 3.0
    smoke.one_shot = true
    var smoke_process: ParticleProcessMaterial = ParticleProcessMaterial.new()
    smoke_process.direction = Vector3.UP
    smoke_process.spread = 36.0
    smoke_process.initial_velocity_min = 0.5
    smoke_process.initial_velocity_max = 1.6
    smoke_process.scale_min = 0.16
    smoke_process.scale_max = 0.42
    smoke_process.gravity = Vector3(0.0, -0.03, 0.0)
    smoke.process_material = smoke_process
    var smoke_quad: QuadMesh = QuadMesh.new()
    smoke_quad.size = Vector2(0.75, 0.75)
    var smoke_material: StandardMaterial3D = StandardMaterial3D.new()
    smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    smoke_material.albedo_color = Color(0.16, 0.16, 0.16, 0.55)
    smoke_quad.material = smoke_material
    smoke.draw_pass_1 = smoke_quad
    add_child(smoke)
    smoke.restart()

func destroy_vehicle() -> void:
    if destroyed:
        return
    if ammo_rack.catastrophic_triggered:
        cook_off()
        return
    destroyed = true
    repairing = false
    repair_timer.stop()
    velocity = Vector3.ZERO
    set_physics_process(false)
    set_collision_layer_value(2, false)
    set_collision_mask_value(1, false)
    tank_destroyed.emit()
    status_changed.emit()
