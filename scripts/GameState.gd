extends Node

signal player_tank_changed(tank: TankBase)
signal match_started(player: TankBase, enemies: Array[TankBase])
signal match_ended(player_won: bool)
signal projectile_impact(target: Node, hit_position: Vector3, hit_normal: Vector3, travel_direction: Vector3, penetration_mm: float, incidence_angle_deg: float)
signal selection_changed(tank_name: String)

const TANK_SCENE: PackedScene = preload("res://scenes/TankBase.tscn")
const TANK_ORDER: Array[String] = ["Churchill", "Hetzer", "IS-2", "KV-1", "Panther", "Panzer IV", "Pershing", "Sherman", "StuG III", "T-34", "Tiger", "Tiger II"]

var selected_tank_name: String = "Panther"
var player_tank: TankBase
var bot_tanks: Array[TankBase] = []
var match_active: bool = false
var match_elapsed: float = 0.0
var kills: int = 0
var tank_catalog: Dictionary = {}

func _ready() -> void:
    _build_catalog()

func _process(delta: float) -> void:
    if match_active:
        match_elapsed += delta

func _build_catalog() -> void:
    tank_catalog.clear()
    tank_catalog["Churchill"] = TankData.build("Churchill", 38.5, 350.0, 25.0, 3.2, 102.0, 64.0, 51.0, 75.0, 5.2, 619.0, 91.0, 26.0, 2.1, 0.68, 0.79, 6.7, 0.076, 0.31, 18.0, 58.0, 100.0, "Heavy infantry tank: dense frontal protection, slow mobility and dependable rapid fire.")
    tank_catalog["Hetzer"] = TankData.build("Hetzer", 15.8, 160.0, 42.0, 7.0, 60.0, 20.0, 20.0, 75.0, 4.7, 925.0, 120.0, 0.0, 1.7, 0.94, 0.88, 6.8, 0.075, 0.29, 28.0, 66.0, 86.0, "Low-profile tank destroyer with a very strong sloped front and no traversing turret.")
    tank_catalog["IS-2"] = TankData.build("IS-2", 46.0, 520.0, 37.0, 6.0, 100.0, 90.0, 60.0, 122.0, 19.5, 800.0, 180.0, 18.0, 3.2, 0.72, 0.83, 25.0, 0.122, 0.27, 16.0, 64.0, 115.0, "Heavy breakthrough tank with a devastating 122 mm cannon and slow reload cycle.")
    tank_catalog["KV-1"] = TankData.build("KV-1", 45.0, 500.0, 34.0, 5.0, 75.0, 70.0, 70.0, 76.2, 8.5, 680.0, 92.0, 18.0, 2.7, 0.70, 0.78, 6.8, 0.076, 0.31, 17.0, 56.0, 105.0, "Early heavy tank with broad protection and poor power-to-weight performance.")
    tank_catalog["Panther"] = TankData.build("Panther", 44.8, 700.0, 46.0, 4.0, 80.0, 50.0, 40.0, 75.0, 7.0, 935.0, 138.0, 22.0, 1.6, 0.88, 0.86, 6.8, 0.075, 0.28, 20.0, 72.0, 115.0, "Long-range medium tank with excellent gun velocity, accuracy and sloped frontal hull.")
    tank_catalog["Panzer IV"] = TankData.build("Panzer IV", 25.0, 300.0, 38.0, 8.0, 50.0, 30.0, 20.0, 75.0, 6.0, 740.0, 99.0, 25.0, 1.9, 0.87, 0.83, 6.8, 0.075, 0.30, 23.0, 58.0, 92.0, "Balanced medium tank with straight armor and a practical rate of fire.")
    tank_catalog["Pershing"] = TankData.build("Pershing", 41.7, 500.0, 40.0, 8.0, 102.0, 76.0, 51.0, 90.0, 8.2, 853.0, 126.0, 20.0, 1.9, 0.81, 0.84, 10.0, 0.090, 0.29, 19.0, 68.0, 108.0, "Versatile medium-heavy tank with a potent 90 mm cannon and balanced protection.")
    tank_catalog["Sherman"] = TankData.build("Sherman", 30.3, 400.0, 40.0, 7.0, 51.0, 38.0, 38.0, 75.0, 5.8, 792.0, 92.0, 30.0, 1.4, 0.96, 0.83, 6.8, 0.075, 0.30, 26.0, 62.0, 98.0, "Highly mobile medium tank with quick turret traverse and stable gun handling.")
    tank_catalog["StuG III"] = TankData.build("StuG III", 24.0, 300.0, 40.0, 7.0, 80.0, 30.0, 30.0, 75.0, 5.0, 925.0, 120.0, 0.0, 1.6, 0.90, 0.85, 6.8, 0.075, 0.29, 27.0, 64.0, 96.0, "Low silhouette assault gun with strong frontal plate and quick firing cycle.")
    tank_catalog["T-34"] = TankData.build("T-34", 30.9, 500.0, 53.0, 7.0, 47.0, 45.0, 45.0, 76.2, 5.7, 680.0, 94.0, 34.0, 1.5, 1.04, 0.81, 6.8, 0.076, 0.31, 30.0, 70.0, 104.0, "Fast Soviet medium tank with strong mobility, sloped armor and agile steering.")
    tank_catalog["Tiger"] = TankData.build("Tiger", 56.9, 650.0, 38.0, 8.0, 100.0, 82.0, 82.0, 88.0, 8.2, 773.0, 148.0, 28.0, 1.9, 0.71, 0.88, 10.0, 0.088, 0.29, 17.0, 66.0, 112.0, "Box-armored heavy tank with highly accurate 88 mm cannon and substantial side protection.")
    tank_catalog["Tiger II"] = TankData.build("Tiger II", 69.8, 800.0, 38.0, 5.0, 150.0, 80.0, 80.0, 88.0, 10.5, 1000.0, 165.0, 22.0, 2.2, 0.63, 0.90, 10.0, 0.088, 0.27, 14.0, 70.0, 128.0, "Very heavy tank with massive frontal protection and a lethal high-velocity KwK 43.")

func set_selected_tank(tank_name: String) -> bool:
    if not tank_catalog.has(tank_name):
        return false
    selected_tank_name = tank_name
    selection_changed.emit(tank_name)
    return true

func get_selected_data() -> TankData:
    return tank_catalog.get(selected_tank_name) as TankData

func get_tank_names() -> Array[String]:
    return TANK_ORDER.duplicate()

func get_visual_profile(tank_name: String) -> Dictionary:
    var profile: Dictionary = {"hull_scale": Vector3.ONE, "turret_scale": Vector3.ONE, "barrel_scale": Vector3.ONE, "turret_visible": true, "hull_shape": Vector3(3.0, 1.2, 5.0), "turret_radius": 1.15, "turret_height": 0.65, "barrel_length": 3.6}
    if tank_name == "Churchill":
        profile["hull_scale"] = Vector3(1.10, 1.16, 1.12)
        profile["hull_shape"] = Vector3(3.25, 1.35, 5.35)
    elif tank_name == "Hetzer":
        profile["hull_scale"] = Vector3(0.90, 0.74, 0.98)
        profile["turret_visible"] = false
        profile["hull_shape"] = Vector3(2.75, 0.92, 4.55)
        profile["barrel_length"] = 3.9
    elif tank_name == "IS-2":
        profile["hull_scale"] = Vector3(1.10, 1.05, 1.08)
        profile["turret_scale"] = Vector3(1.08, 1.08, 1.08)
        profile["barrel_scale"] = Vector3(1.25, 1.25, 1.25)
        profile["barrel_length"] = 4.1
    elif tank_name == "KV-1":
        profile["hull_scale"] = Vector3(1.09, 1.10, 1.08)
        profile["turret_radius"] = 1.28
    elif tank_name == "Panther":
        profile["hull_scale"] = Vector3(1.03, 0.98, 1.08)
        profile["turret_scale"] = Vector3(0.98, 0.94, 1.03)
        profile["barrel_scale"] = Vector3(0.88, 0.88, 1.18)
    elif tank_name == "Panzer IV":
        profile["hull_scale"] = Vector3(0.98, 0.96, 1.02)
        profile["turret_radius"] = 1.08
    elif tank_name == "Pershing":
        profile["hull_scale"] = Vector3(1.05, 1.03, 1.05)
        profile["turret_radius"] = 1.24
        profile["barrel_length"] = 3.9
    elif tank_name == "Sherman":
        profile["hull_scale"] = Vector3(1.02, 0.98, 1.02)
        profile["turret_radius"] = 1.18
    elif tank_name == "StuG III":
        profile["hull_scale"] = Vector3(0.94, 0.78, 1.02)
        profile["turret_visible"] = false
        profile["hull_shape"] = Vector3(2.85, 0.96, 4.75)
        profile["barrel_length"] = 3.8
    elif tank_name == "T-34":
        profile["hull_scale"] = Vector3(0.98, 0.92, 1.05)
        profile["turret_radius"] = 1.06
    elif tank_name == "Tiger":
        profile["hull_scale"] = Vector3(1.10, 1.06, 1.09)
        profile["turret_radius"] = 1.24
    elif tank_name == "Tiger II":
        profile["hull_scale"] = Vector3(1.16, 1.12, 1.14)
        profile["turret_radius"] = 1.34
        profile["barrel_length"] = 4.3
    return profile

func build_hull_mesh(profile: Dictionary) -> BoxMesh:
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = profile.get("hull_shape", Vector3(3.0, 1.2, 5.0))
    return mesh

func build_turret_mesh(profile: Dictionary) -> CylinderMesh:
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = profile.get("turret_radius", 1.15)
    mesh.bottom_radius = profile.get("turret_radius", 1.15)
    mesh.height = profile.get("turret_height", 0.65)
    mesh.radial_segments = 16
    return mesh

func build_barrel_mesh(profile: Dictionary) -> CylinderMesh:
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = 0.105
    mesh.bottom_radius = 0.14
    mesh.height = profile.get("barrel_length", 3.6)
    mesh.radial_segments = 10
    mesh.rotation_degrees = Vector3(90.0, 0.0, 0.0)
    return mesh

func spawn_tank(tank_name: String, position: Vector3, player_controlled: bool) -> TankBase:
    var data: TankData = tank_catalog.get(tank_name) as TankData
    if data == null:
        return null
    var tank: TankBase = TANK_SCENE.instantiate() as TankBase
    if tank == null:
        return null
    tank.global_position = position
    get_tree().current_scene.add_child(tank)
    tank.configure(data, player_controlled)
    return tank

func start_match(origin: Vector3 = Vector3.ZERO) -> TankBase:
    end_match()
    kills = 0
    match_elapsed = 0.0
    player_tank = spawn_tank(selected_tank_name, origin + Vector3(0.0, 0.0, 10.0), true)
    if player_tank == null:
        return null
    player_tank.name = "PlayerTank"
    player_tank.tank_destroyed.connect(_on_player_destroyed)
    bot_tanks.clear()
    var enemy_names: Array[String] = ["Tiger", "T-34", "Panther", "Sherman", "IS-2", "Panzer IV"]
    var spawn_positions: Array[Vector3] = [Vector3(-22.0, 0.0, -34.0), Vector3(22.0, 0.0, -34.0), Vector3(-34.0, 0.0, -15.0), Vector3(34.0, 0.0, -14.0), Vector3(-12.0, 0.0, -55.0), Vector3(14.0, 0.0, -54.0)]
    for index: int in range(enemy_names.size()):
        var bot: TankBase = spawn_tank(enemy_names[index], origin + spawn_positions[index], false)
        if bot == null:
            continue
        bot.name = "Enemy_%02d" % index
        bot.tank_destroyed.connect(_on_bot_destroyed.bind(bot))
        bot_tanks.append(bot)
    match_active = true
    player_tank_changed.emit(player_tank)
    match_started.emit(player_tank, bot_tanks)
    return player_tank

func find_nearest_enemy(source: TankBase) -> TankBase:
    var best: TankBase
    var best_distance: float = INF
    if source.is_player:
        for bot: TankBase in bot_tanks:
            if is_instance_valid(bot) and not bot.destroyed:
                var d: float = source.global_position.distance_squared_to(bot.global_position)
                if d < best_distance:
                    best_distance = d
                    best = bot
        return best
    if is_instance_valid(player_tank) and not player_tank.destroyed:
        return player_tank
    return null

func end_match() -> void:
    match_active = false
    if is_instance_valid(player_tank):
        player_tank.queue_free()
    player_tank = null
    for bot: TankBase in bot_tanks:
        if is_instance_valid(bot):
            bot.queue_free()
    bot_tanks.clear()

func _on_player_destroyed() -> void:
    if match_active:
        match_active = false
        match_ended.emit(false)

func _on_bot_destroyed(bot: TankBase) -> void:
    kills += 1
    if not match_active:
        return
    var survivors: int = 0
    for enemy: TankBase in bot_tanks:
        if is_instance_valid(enemy) and not enemy.destroyed:
            survivors += 1
    if survivors == 0 and is_instance_valid(player_tank) and not player_tank.destroyed:
        match_active = false
        match_ended.emit(true)
