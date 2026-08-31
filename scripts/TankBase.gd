class_name TankBase
extends CharacterBody3D

signal module_damaged(module_name: String, health: float)
signal module_repaired(module_name: String)
signal tank_destroyed()
signal repair_started(module_name: String, duration: float)
signal repair_finished(module_name: String)
signal fired(projectile: Projectile)
signal combat_event(text: String)
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
var ability_remaining: float = 0.0
var ability_cooldown_remaining: float = 0.0
var steering_input: float = 0.0
var throttle_input: float = 0.0
var turret_input: float = 0.0
var bot_cooldown: float = 0.0
var bot_difficulty: float = 1.0
var target_tank: TankBase
var target_lock_time: float = 0.0
var last_hit_angle: float = 0.0
var last_hit_result: String = "READY"

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
    ability_remaining = 0.0
    ability_cooldown_remaining = 0.0
    bot_cooldown = 1.5
    target_tank = null
    target_lock_time = 0.0
    last_hit_angle = 0.0
    last_hit_result = "READY"
    _apply_visual_profile()
    engine.reset_state()
    ammo_rack.reset_state()
    turret_ring.reset_state()
    crew.reset_state()
    set_physics_process(true)
    set_collision_layer_value(2, true)
    set_collision_mask_value(1, true)
    status_changed.emit()

func _apply_visual_profile() -> void:
    if tank_data == null:
        return
    var profile: Dictionary = GameState.get_visual_profile(tank_data.tank_name)
    hull_mesh.mesh = GameState.build_hull_mesh(profile)
    turret_mesh.mesh = GameState.build_turret_mesh(profile)
    gun_barrel.mesh = GameState.build_barrel_mesh(profile)
    hull_mesh.scale = profile.get("hull_scale", Vector3.ONE)
    turret.scale = profile.get("turret_scale", Vector3.ONE)
    gun_barrel.scale = profile.get("barrel_scale", Vector3.ONE)
    turret.visible = profile.get("turret_visible", true)
    var hull_material: StandardMaterial3D = StandardMaterial3D.new()
    hull_material.albedo_color = profile.get("color", Color("465044"))
    hull_material.roughness = 0.92
    hull_mesh.material_override = hull_material
    var turret_material: StandardMaterial3D = StandardMaterial3D.new()
    turret_material.albedo_color = profile.get("accent", Color("2b302c"))
    turret_material.roughness = 0.88
    turret_mesh.material_override = turret_material
    gun_barrel.material_override = turret_material

func _exit_tree() -> void:
    if GameState.projectile_impact.is_connected(_on_projectile_impact):
        GameState.projectile_impact.disconnect(_on_projectile_impact)

func _physics_process(delta: float) -> void:
    if tank_data == null or destroyed:
        return
    reload_remaining = maxf(0.0, reload_remaining - delta)
    aim_remaining = maxf(0.0, aim_remaining - delta)
    ability_cooldown_remaining = maxf(0.0, ability_cooldown_remaining - delta)
    ability_remaining = maxf(0.0, ability_remaining - delta)
    if repairing:
        velocity = Vector3.ZERO
        move_and_slide()
        return
    if is_player:
        _read_player_input()
        if Input.is_action_just_pressed("fire"):
            fire_cannon()
        if Input.is_action_just_pressed("ability"):
            activate_ability()
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
    if distance < 0.1:
        throttle_input = 0.0
        steering_input = 0.0
        turret_input = 0.0
        return
    var desired: Vector3 = flat_target.normalized()
    var forward: Vector3 = -global_transform.basis.z
    var alignment: float = forward.dot(desired)
    var cross_value: float = forward.cross(desired).y
    var role: String = tank_data.doctrine
    if role == "AMBUSH" or role == "SNIPER":
        if distance < 24.0:
            throttle_input = -0.10
        elif distance < 50.0:
            throttle_input = 0.15
        else:
            throttle_input = 0.55
    elif role == "FLANK":
        var side_sign: float = -1.0
        if int(get_instance_id()) % 2 == 0:
            side_sign = 1.0
        var flank_dir: Vector3 = (desired + Vector3(-desired.z * side_sign, 0.0, desired.x * side_sign) * 0.75).normalized()
        cross_value = forward.cross(flank_dir).y
        throttle_input = 0.78
    elif role == "WALL" or role == "BREACH" or role == "BOSS":
        if distance > 15.0:
            throttle_input = 0.72
        else:
            throttle_input = -0.05
    else:
        if distance > 25.0:
            throttle_input = 0.55
        else:
            throttle_input = 0.08
    steering_input = clampf(cross_value * 1.6, -1.0, 1.0)
    turret_input = clampf(cross_value * 2.5, -1.0, 1.0)
    var required_alignment: float = 0.14 / maxf(0.7, bot_difficulty)
    if distance <= tank_data.bot_fire_range * bot_difficulty and absf(cross_value) < required_alignment:
        target_lock_time += delta * bot_difficulty
    else:
        target_lock_time = maxf(0.0, target_lock_time - delta * 0.8)
    if target_lock_time > 0.42 and bot_cooldown <= 0.0 and alignment > -0.25:
        fire_cannon()
        bot_cooldown = maxf(0.65, tank_data.reload_time_sec * (1.08 - 0.12 * bot_difficulty))
        target_lock_time = 0.0
    if tank_data.ability_name != "" and ability_cooldown_remaining <= 0.0 and distance < 45.0 and role == "BOSS":
        activate_ability()

func _update_movement(delta: float) -> void:
    var speed_kmh: float = tank_data.top_speed_kmh
    if throttle_input < 0.0:
        speed_kmh = tank_data.reverse_speed_kmh
    var target_speed_ms: float = speed_kmh / 3.6
    var forward: Vector3 = -global_transform.basis.z
    var desired_velocity: Vector3 = forward * throttle_input * target_speed_ms
    if not crew.can_accelerate() or not engine.operational:
        desired_velocity = Vector3.ZERO
    var response: float = 3.0 * tank_data.acceleration_factor * engine_factor()
    if ability_remaining > 0.0 and tank_data.ability_name == "Overdrive":
        response *= 1.25
        desired_velocity *= 1.16
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
    if ability_remaining > 0.0 and tank_data.ability_name == "Rapid Turret":
        rate *= 1.6
    turret.rotate_y(turret_input * rate * delta)

func fire_cannon() -> void:
    if tank_data == null or destroyed or repairing:
        return
    if reload_remaining > 0.0 or aim_remaining > 0.0 or not ammo_rack.operational or not crew.gunner_alive:
        return
    var projectile: Projectile = preload("res://scenes/Projectile.tscn").instantiate() as Projectile
    if projectile == null:
        return
    get_tree().current_scene.add_child(projectile)
    projectile.setup(muzzle.global_position, -muzzle.global_transform.basis.z, tank_data, self)
    reload_remaining = tank_data.reload_time_sec * crew.reload_multiplier()
    aim_remaining = tank_data.aim_time_sec * crew.aim_multiplier()
    if ability_remaining > 0.0 and tank_data.ability_name == "Deadeye":
        aim_remaining = 0.0
    fired.emit(projectile)
    combat_event.emit("FIRE  %s" % tank_data.tank_name.to_upper())
    _spawn_muzzle_flash()
    status_changed.emit()

func activate_ability() -> void:
    if tank_data == null or destroyed or ability_cooldown_remaining > 0.0:
        return
    ability_remaining = tank_data.ability_duration
    ability_cooldown_remaining = tank_data.ability_cooldown
    if tank_data.ability_name == "Fortify":
        combat_event.emit("FORTIFY — frontal armor reinforced")
    elif tank_data.ability_name == "Deadeye":
        aim_remaining = 0.0
        combat_event.emit("DEADEYE — aim locked")
    elif tank_data.ability_name == "Overdrive":
        combat_event.emit("OVERDRIVE — power surge")
    elif tank_data.ability_name == "Rapid Turret":
        combat_event.emit("RAPID TURRET — traverse boosted")
    elif tank_data.ability_name == "Devastation":
        combat_event.emit("DEVASTATION — next penetration empowered")
    elif tank_data.ability_name == "Stabilize":
        aim_remaining = 0.0
        combat_event.emit("STABILIZE — gun settled")
    else:
        combat_event.emit("ABILITY — %s" % tank_data.ability_name)
    status_changed.emit()

func _on_projectile_impact(target: Node, hit_position: Vector3, hit_normal: Vector3, travel_direction: Vector3, penetration_mm: float, incidence_angle_deg: float) -> void:
    if destroyed or target != self:
        return
    var result: Dictionary = resolve_armor_hit(hit_position, hit_normal, travel_direction, penetration_mm, incidence_angle_deg)
    last_hit_angle = incidence_angle_deg
    if bool(result.get("penetrated", false)):
        apply_spall(hit_position, travel_direction, penetration_mm)
        last_hit_result = "PENETRATION"
        combat_event.emit("PENETRATION  effective %dmm" % roundi(float(result.get("effective_armor_mm", 0.0))))
    else:
        last_hit_result = "NON-PENETRATION"
        combat_event.emit("NON-PENETRATION  %d°" % roundi(incidence_angle_deg))
    status_changed.emit()

func resolve_armor_hit(hit_position: Vector3, hit_normal: Vector3, travel_direction: Vector3, projectile_penetration: float, incidence_angle: float) -> Dictionary:
    var local_hit: Vector3 = to_local(hit_position)
    var armor: float = tank_data.armor_side_mm
    if local_hit.z < -1.0:
        armor = tank_data.armor_front_mm
    elif local_hit.z > 1.0:
        armor = tank_data.armor_rear_mm
    if ability_remaining > 0.0 and tank_data.ability_name == "Fortify" and local_hit.z < 0.25:
        armor *= 1.25
    var normal: Vector3 = hit_normal.normalized()
    var incoming: Vector3 = -travel_direction.normalized()
    var cosine: float = clampf(absf(normal.dot(incoming)), 0.10, 1.0)
    var effective_armor: float = armor / cosine
    var penetrated: bool = projectile_penetration >= effective_armor
    var hull_damage: float = 0.0
    if penetrated:
        hull_damage = clampf((projectile_penetration / maxf(effective_armor, 1.0)) * tank_data.impact_damage_factor, 6.0, tank_data.max_hull_damage)
        if ability_remaining > 0.0 and tank_data.ability_name == "Devastation":
            hull_damage *= 1.28
        hull_health = maxf(0.0, hull_health - hull_damage)
        module_damaged.emit("Hull", hull_health)
        if hull_health <= 0.0:
            destroy_vehicle()
    return {"penetrated": penetrated, "effective_armor_mm": effective_armor, "impact_angle_deg": incidence_angle, "hull_damage": hull_damage}

func apply_spall(hit_position: Vector3, direction: Vector3, projectile_penetration: float) -> void:
    var local_hit: Vector3 = to_local(hit_position)
    var local_direction: Vector3 = global_transform.basis.inverse() * direction.normalized()
    local_direction = local_direction.normalized()
    var points: Array[Vector3] = [Vector3(0.0, 0.55, 0.70), Vector3(0.0, 0.82, -0.55), Vector3(0.0, 1.02, 0.0), Vector3(0.62, 1.04, 0.08), Vector3(-0.60, 1.00, 0.08)]
    var weights: Array[float] = [1.0, 1.0, 0.82, 0.58, 0.48]
    for index: int in range(points.size()):
        var offset: Vector3 = points[index] - local_hit
        var distance_to_module: float = offset.length()
        if distance_to_module < 0.05:
            continue
        var cone_factor: float = maxf(0.0, local_direction.dot(offset.normalized()))
        var distance_factor: float = 1.0 / maxf(0.8, distance_to_module)
        var severity: float = projectile_penetration * cone_factor * distance_factor * weights[index]
        if severity < 16.0:
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
        elif index == 4:
            if severity >= tank_data.crew_knockout_threshold:
                crew.lose_member("driver")
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
    var duration: float = 2.6
    if target == "AmmoRack":
        duration = 4.0
    elif target == "TurretRing":
        duration = 3.4
    repair_timer.start(duration)
    repair_started.emit(target, duration)
    combat_event.emit("REPAIRING %s" % target.to_upper())
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
    combat_event.emit("RESTORED %s" % repair_target.to_upper())
    repair_target = ""
    status_changed.emit()

func _on_engine_destroyed(_component: EngineComponent) -> void:
    module_damaged.emit("Engine", 0.0)
    combat_event.emit("ENGINE DISABLED")
    status_changed.emit()

func _on_ammo_rack_critical(_component: AmmoRackComponent) -> void:
    combat_event.emit("AMMO COOK-OFF!")
    cook_off()

func _on_turret_ring_damaged(component: TurretRingComponent) -> void:
    module_damaged.emit("TurretRing", component.health)
    status_changed.emit()

func _on_component_repaired(component: Node) -> void:
    module_repaired.emit(component.name)
    status_changed.emit()

func _on_crew_member_lost(role: String) -> void:
    module_damaged.emit(role, 0.0)
    combat_event.emit("CREW HIT — %s" % role.to_upper())
    status_changed.emit()

func _on_crew_member_repaired(role: String) -> void:
    module_repaired.emit(role)
    status_changed.emit()

func _on_fire_risk_changed(_active: bool) -> void:
    status_changed.emit()

func _spawn_muzzle_flash() -> void:
    var flash: GPUParticles3D = GPUParticles3D.new()
    flash.amount = 10
    flash.lifetime = 0.20
    flash.one_shot = true
    var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
    process_material.direction = -muzzle.global_transform.basis.z
    process_material.spread = 16.0
    process_material.initial_velocity_min = 1.0
    process_material.initial_velocity_max = 4.0
    process_material.scale_min = 0.12
    process_material.scale_max = 0.28
    flash.process_material = process_material
    var quad: QuadMesh = QuadMesh.new()
    quad.size = Vector2(0.35, 0.35)
    flash.draw_pass_1 = quad
    muzzle.add_child(flash)
    flash.restart()

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
    _spawn_destruction_particles()
    tank_destroyed.emit()
    status_changed.emit()

func _spawn_destruction_particles() -> void:
    var fire: GPUParticles3D = GPUParticles3D.new()
    fire.amount = 26
    fire.lifetime = 1.4
    fire.one_shot = true
    var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
    process_material.direction = Vector3.UP
    process_material.spread = 38.0
    process_material.initial_velocity_min = 1.0
    process_material.initial_velocity_max = 5.0
    process_material.scale_min = 0.12
    process_material.scale_max = 0.38
    process_material.gravity = Vector3(0.0, -0.2, 0.0)
    fire.process_material = process_material
    var quad: QuadMesh = QuadMesh.new()
    quad.size = Vector2(0.5, 0.5)
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(1.0, 0.32, 0.05, 0.85)
    quad.material = material
    fire.draw_pass_1 = quad
    add_child(fire)
    fire.restart()

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
