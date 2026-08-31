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
    var p: Dictionary = GameState.get_visual_profile(tank_data.tank_name)
    hull_mesh.mesh = GameState.build_hull_mesh(p)
    turret_mesh.mesh = GameState.build_turret_mesh(p)
    gun_barrel.mesh = GameState.build_barrel_mesh(p)
    hull_mesh.scale = p.get("hull_scale", Vector3.ONE)
    turret.scale = p.get("turret_scale", Vector3.ONE)
    gun_barrel.scale = p.get("barrel_scale", Vector3.ONE)
    turret.visible = p.get("turret_visible", true)
    var hull_mat := StandardMaterial3D.new()
    hull_mat.albedo_color = p.get("color", Color("465044"))
    hull_mat.roughness = 0.92
    hull_mesh.material_override = hull_mat
    var turret_mat := StandardMaterial3D.new()
    turret_mat.albedo_color = p.get("accent", Color("2b302c"))
    turret_mat.roughness = 0.88
    turret_mesh.material_override = turret_mat
    gun_barrel.material_override = turret_mat

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
        if Input.is_action_just_pressed("repair"):
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
    var to_target := target_tank.global_position - global_position
    var flat := Vector3(to_target.x, 0.0, to_target.z)
    var distance := flat.length()
    if distance < 0.1:
        return
    var desired := flat.normalized()
    var forward := -global_transform.basis.z
    var alignment := forward.dot(desired)
    var cross_value := forward.cross(desired).y
    var role := tank_data.doctrine
    if role == "AMBUSH" or role == "SNIPER":
        throttle_input = -0.10 if distance < 24.0 else (0.15 if distance < 50.0 else 0.55)
    elif role == "FLANK":
        var side_sign := -1.0 if int(get_instance_id()) % 2 == 0 else 1.0
        var flank_dir := (desired + Vector3(-desired.z * side_sign, 0.0, desired.x * side_sign) * 0.75).normalized()
        cross_value = forward.cross(flank_dir).y
        throttle_input = 0.75
    elif role == "WALL" or role == "BREACH" or role == "BOSS":
        throttle_input = 0.72 if distance > 15.0 else -0.05
    else:
        throttle_input = 0.55 if distance > 25.0 else 0.08
    steering_input = clampf(cross_value * 1.6, -1.0, 1.0)
    turret_input = clampf(cross_value * 2.5, -1.0, 1.0)
    var required_alignment := 0.14 / maxf(0.7, bot_difficulty)
    if distance <= tank_data.bot_fire_range * bot_difficulty and absf(cross_value) < required_alignment:
        target_lock_time += delta * bot_difficulty
    else:
        target_lock_time = maxf(0.0, target_lock_time - delta * 0.8)
    if target_lock_time > 0.42 and bot_cooldown <= 0.0:
        fire_cannon()
        bot_cooldown = maxf(0.65, tank_data.reload_time_sec * (1.08 - 0.12 * bot_difficulty))
        target_lock_time = 0.0
    if tank_data.ability_name != "" and ability_cooldown_remaining <= 0.0 and distance < 45.0 and role == "BOSS":
        activate_ability()

func _update_movement(delta: float) -> void:
    var speed_kmh := tank_data.top_speed_kmh
    if throttle_input < 0.0:
        speed_kmh = tank_data.reverse_speed_kmh
    var target_speed_ms := speed_kmh / 3.6
    var forward := -global_transform.basis.z
    var desired_velocity := forward * throttle_input * target_speed_ms
    if not crew.can_accelerate() or not engine.operational:
        desired_velocity = Vector3.ZERO
    var response := 3.0 * tank_data.acceleration_factor * engine_factor()
    if ability_remaining > 0.0 and tank_data.ability_name == "Overdrive":
        response *= 1.25
        desired_velocity *= 1.16
    velocity = velocity.move_toward(desired_velocity, response * delta)
    var turn_rate := deg_to_rad(tank_data.hull_turn_deg_sec) * crew.steering_multiplier()
    if absf(throttle_input) > 0.05:
        rotate_y(steering_input * turn_rate * delta)
    move_and_slide()

func engine_factor() -> float:
    return 0.55 if engine.fire_risk else 1.0

func _update_turret(delta: float) -> void:
    if not turret.visible or turret_ring.rotation_multiplier <= 0.0:
        return
    var rate := deg_to_rad(tank_data.turret_traverse_deg_sec) * turret_ring.rotation_multiplier
    if ability_remaining > 0.0 and tank_data.ability_name == "Rapid Turret":
        rate *= 1.6
    rotate_turret_local(turret_input * rate * delta)

func rotate_turret_local(amount: float) -> void:
    turret.rotate_y(amount)

func fire_cannon() -> void:
    if tank_data == null or destroyed or repairing:
        return
    if reload_remaining > 0.0 or aim_remaining > 0.0 or not ammo_rack.operational or not crew.gunner_alive:
        return
    var projectile := preload("res://scenes/Projectile.tscn").instantiate() as Projectile
    if projectile == null:
        return
    get_tree().current_scene.add_child(projectile)
    projectile.setup(muzzle.global_position, -muzzle.global_transform.basis.z, tank_data, self)
    reload_remaining = tank_data.reload_time_sec * crew.reload_multiplier()
    aim_remaining = tank_data.aim_time_sec * crew.aim_multiplier()
    fired.emit(projectile)
    combat_event.emit("FIRE  %s" % tank_data.tank_name.to_upper())
    _spawn_muzzle_flash()
    status_changed.emit()

func activate_ability() -> void:
    if ability_cooldown_remaining > 0.0 or tank_data.ability_name.is_empty() or destroyed:
        return
    ability_remaining = tank_data.ability_duration
    ability_cooldown_remaining = tank_data.ability_cooldown
    if tank_data.ability_name == "Fortify":
        combat_event.emit("FORTIFY — frontal armor reinforced")
    elif tank_data.ability_name == "Deadeye":
        aim_remaining = 0.0
        combat_event.emit("DEADEYE — perfect aim")
    elif tank_data.ability_name == "Overdrive":
        combat_event.emit("OVERDRIVE — power surge")
    elif tank_data.ability_name == "Rapid Turret":
        combat_event.emit("RAPID TURRET — traverse boosted")
    elif tank_data.ability_name == "Devastation":
        combat_event.emit("DEVASTATION — next round empowered")
    else:
        combat_event.emit("ABILITY — %s" % tank_data.ability_name)
    status_changed.emit()

func _on_projectile_impact(target: Node, hit_position: Vector3, hit_normal: Vector3, travel_direction: Vector3, penetration_mm: float, incidence_angle_deg: float) -> void:
    if destroyed or target != self:
        return
    var result := resolve_armor_hit(hit_position, hit_normal, travel_direction, penetration_mm, incidence_angle_deg)
    last_hit_angle = incidence_angle_deg
    if bool(result.get("penetrated", false)):
        apply_spall(hit_position, travel_direction, penetration_mm)
        last_hit_result = "PENETRATION"
        combat_event.emit("PENETRATION  %dmm" % roundi(result.get("effective_armor_mm", 0.0)))
    else:
        last_hit_result = "BOUNCE"
        combat_event.emit("NON-PENETRATION  %d°" % roundi(incidence_angle_deg))
    status_changed.emit()

func resolve_armor_hit(hit_position: Vector3, hit_normal: Vector3, travel_direction: Vector3, projectile_penetration: float, incidence_angle: float) -> Dictionary:
    var local_hit := to_local(hit_position)
    var armor := tank_data.armor_side_mm
    if local_hit.z < -1.0:
        armor = tank_data.armor_front_mm
    elif local_hit.z > 1.0:
        armor = tank_data.armor_rear_mm
    if ability_remaining > 0.0 and tank_data.ability_name == "Fortify" and local_hit.z < 0.25:
        armor *= 1.25
    var normal := hit_normal.normalized()
    var incoming := -travel_direction.normalized()
    var cosine := clampf(absf(normal.dot(incoming)), 0.10, 1.0)
    var effective_armor := armor / cosine
    var penetrated := projectile_penetration >= effective_armor
    var hull_damage := 0.0
    if penetrated:
        hull_damage = clampf((projectile_penetration / maxf(effective_armor, 1.0)) * tank_data.impact_damage_factor, 6.0, tank_data.max_hull_damage)
        if ability_remaining > 0.0 and tank_data.ability_name == "Devastation":
            hull_damage *= 1.28
        hull_health = maxf(0.0, hull_health - hull_damage)
        module_damaged.emit("Hull", hull_health)
        if hull_health <= 0.0:
            destroy_vehicle()
    return {"penetrated":penetrated,"effective_armor_mm":effective_armor,"impact_angle_deg":incidence_angle,"hull_damage":hull_damage}

func apply_spall(hit_position: Vector3, direction: Vector3, projectile_penetration: float) -> void:
    var local_hit := to_local(hit_position)
    var local_direction := global_transform.basis.inverse() * direction.normalized()
    var points: Array[Vector3] = [Vector3(0,0.55,0.7),Vector3(0,0.82,-0.55),Vector3(0,1.02,0),Vector3(0.62,1.04,0.08),Vector3(-0.60,1.0,0.08)]
    var weights: Array[float] = [1.0,1.0,0.82,0.58,0.48]
    for i in range(points.size()):
        var offset := points[i] - local_hit
        var dist := offset.length()
        if dist < 0.05:
            continue
        var cone := maxf(0.0, local_direction.dot(offset.normalized()))
        var severity := projectile_penetration * cone * (1.0 / maxf(0.8,dist)) * weights[i]
        if severity < 16.0:
            continue
        match i:
            0:
                engine.apply_damage(severity)
                module_damaged.emit("Engine", engine.health)
            1:
                ammo_rack.apply_damage(severity, severity >= tank_data.ammo_cookoff_threshold)
                module_damaged.emit("AmmoRack", ammo_rack.health)
            2:
                turret_ring.apply_damage(severity, severity >= tank_data.turret_ring_lock_threshold)
                module_damaged.emit("TurretRing", turret_ring.health)
            3:
                if severity >= tank_data.crew_knockout_threshold:
                    crew.lose_member("gunner")
                    module_damaged.emit("Gunner",0)
            4:
                if severity >= tank_data.crew_knockout_threshold:
                    crew.lose_member("driver")
                    module_damaged.emit("Driver",0)
    status_changed.emit()

func start_repair() -> void:
    if destroyed or repairing:
        return
    var target := _find_repair_target()
    if target.is_empty():
        return
    repair_target = target
    repairing = true
    velocity = Vector3.ZERO
    var duration := 2.6
    if target == "AmmoRack": duration = 4.0
    elif target == "TurretRing": duration = 3.4
    repair_timer.start(duration)
    repair_started.emit(target,duration)
    combat_event.emit("REPAIRING %s" % target.to_upper())
    status_changed.emit()

func _find_repair_target() -> String:
    if not engine.operational: return "Engine"
    if not ammo_rack.operational: return "AmmoRack"
    if not turret_ring.operational: return "TurretRing"
    if not crew.gunner_alive: return "Gunner"
    if not crew.driver_alive: return "Driver"
    if not crew.commander_alive: return "Commander"
    if not crew.loader_alive: return "Loader"
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
        "Loader": crew.repair_member("loader")
    repair_finished.emit(repair_target)
    combat_event.emit("RESTORED %s" % repair_target.to_upper())
    repair_target = ""
    status_changed.emit()

func _on_engine_destroyed(_component: EngineComponent) -> void:
    module_damaged.emit("Engine",0.0)
    combat_event.emit("ENGINE DISABLED")
    status_changed.emit()

func _on_ammo_rack_critical(_component: AmmoRackComponent) -> void:
    combat_event.emit("AMMO COOK-OFF!")
    cook_off()

func _on_turret_ring_damaged(component: TurretRingComponent) -> void:
    module_damaged.emit("TurretRing",component.health)
    status_changed.emit()

func _on_component_repaired(component: Node) -> void:
    module_repaired.emit(component.name)
    status_changed.emit()

func _on_crew_member_lost(role: String) -> void:
    module_damaged.emit(role,0.0)
    combat_event.emit("CREW HIT — %s" % role.to_upper())
    status_changed.emit()

func _on_crew_member_repaired(role: String) -> void:
    module_repaired.emit(role)
    status_changed.emit()

func _on_fire_risk_changed(_active: bool) -> void:
    status_changed.emit()

func _spawn_muzzle_flash() -> void:
    var flash := GPUParticles3D.new()
    flash.amount = 10
    flash.lifetime = 0.20
    flash.one_shot = true
    var process := ParticleProcessMaterial.new()
    process.direction = -muzzle.global_transform.basis.z
    process.spread = 16.0
    process.initial_velocity_min = 1.0
    process.initial_velocity_max = 4.0
    process.scale_min = 0.12
    process.scale_max = 0.28
    flash.process_material = process
    var quad := QuadMesh.new()
    quad.size = Vector2(0.35,0.35)
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
    set_collision_layer_value(2,false)
    set_collision_mask_value(1,false)
    turret.visible = false
    _spawn_destruction_particles()
    tank_destroyed.emit()
    status_changed.emit()

func _spawn_destruction_particles() -> void:
    var fire := GPUParticles3D.new()
    fire.amount = 26
    fire.lifetime = 1.4
    fire.one_shot = true
    var pm := ParticleProcessMaterial.new()
    pm.direction = Vector3.UP
    pm.spread = 38.0
    pm.initial_velocity_min = 1.0
    pm.initial_velocity_max = 5.0
    pm.scale_min = 0.12
    pm.scale_max = 0.38
    pm.gravity = Vector3(0,-0.2,0)
    fire.process_material = pm
    var qm := QuadMesh.new()
    qm.size = Vector2(0.5,0.5)
    var mat := StandardMaterial3D.new()
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(1.0,0.32,0.05,0.85)
    qm.material = mat
    fire.draw_pass_1 = qm
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
    set_collision_layer_value(2,false)
    set_collision_mask_value(1,false)
    tank_destroyed.emit()
    status_changed.emit()
