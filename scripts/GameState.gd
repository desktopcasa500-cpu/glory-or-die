extends Node

signal player_tank_changed(tank: TankBase)
signal match_started(player: TankBase, enemies: Array[TankBase])
signal match_ended(player_won: bool)
signal wave_started(wave: int, objective: String)
signal progression_changed()
signal feed_message(text: String)
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
var score: int = 0
var credits: int = 1200
var xp: int = 0
var level: int = 1
var campaign_wave: int = 0
var wave_total: int = 5
var objective: String = ""
var intermission_remaining: float = 0.0
var difficulty: float = 1.0
var tank_catalog: Dictionary = {}
var mastery: Dictionary = {}

const WAVE_INFO: Array[Dictionary] = [
    {"name":"IRON GATE", "objective":"BREAKTHROUGH", "enemies":["Panzer IV","StuG III","T-34"], "reward":450},
    {"name":"HEDGEHOG", "objective":"HOLD THE LINE", "enemies":["Sherman","Panzer IV","Hetzer","T-34"], "reward":650},
    {"name":"COUNTERSTRIKE", "objective":"DESTROY THE ELITE", "enemies":["Panther","Tiger","Panzer IV","StuG III"], "reward":900},
    {"name":"STEEL STORM", "objective":"SURVIVE THE ASSAULT", "enemies":["IS-2","Tiger","Panther","T-34","Sherman"], "reward":1200},
    {"name":"LAST STAND", "objective":"KILL THE COMMAND TANK", "enemies":["Tiger II","Tiger","IS-2","Panther","Hetzer"], "reward":1800}
]

func _ready() -> void:
    _build_catalog()
    for name_value: String in TANK_ORDER:
        mastery[name_value] = 0

func _process(delta: float) -> void:
    if match_active:
        match_elapsed += delta
    elif intermission_remaining > 0.0:
        intermission_remaining = maxf(0.0, intermission_remaining - delta)
        if intermission_remaining <= 0.0 and is_instance_valid(player_tank) and not player_tank.destroyed and campaign_wave < wave_total:
            _start_next_wave()

func _build_catalog() -> void:
    tank_catalog.clear()
    tank_catalog["Churchill"] = TankData.build("Churchill",38.5,350.0,25.0,3.2,102.0,64.0,51.0,75.0,5.2,619.0,91.0,26.0,2.1,0.68,0.79,6.7,0.076,0.31,18.0,58.0,100.0,"Heavy infantry tank. Wins by surviving mistakes and forcing frontal fights.")
    tank_catalog["Hetzer"] = TankData.build("Hetzer",15.8,160.0,42.0,7.0,60.0,20.0,20.0,75.0,4.7,925.0,120.0,0.0,1.7,0.94,0.88,6.8,0.075,0.29,28.0,66.0,86.0,"Tank destroyer. Tiny silhouette, brutal ambush damage and no turret.")
    tank_catalog["IS-2"] = TankData.build("IS-2",46.0,520.0,37.0,6.0,100.0,90.0,60.0,122.0,19.5,800.0,180.0,18.0,3.2,0.72,0.83,25.0,0.122,0.27,16.0,64.0,115.0,"Breakthrough heavy. One hit can decide a fight, but every miss hurts.")
    tank_catalog["KV-1"] = TankData.build("KV-1",45.0,500.0,34.0,5.0,75.0,70.0,70.0,76.2,8.5,680.0,92.0,18.0,2.7,0.70,0.78,6.8,0.076,0.31,17.0,56.0,105.0,"Old-school heavy. Forgiving armor profile with stubborn mobility.")
    tank_catalog["Panther"] = TankData.build("Panther",44.8,700.0,46.0,4.0,80.0,50.0,40.0,75.0,7.0,935.0,138.0,22.0,1.6,0.88,0.86,6.8,0.075,0.28,20.0,72.0,115.0,"Sniper medium. Fast shell, sharp front and rewarding long-range aim.")
    tank_catalog["Panzer IV"] = TankData.build("Panzer IV",25.0,300.0,38.0,8.0,50.0,30.0,20.0,75.0,6.0,740.0,99.0,25.0,1.9,0.87,0.83,6.8,0.075,0.30,23.0,58.0,92.0,"Classic all-rounder. Easy to learn, hard to master positioning.")
    tank_catalog["Pershing"] = TankData.build("Pershing",41.7,500.0,40.0,8.0,102.0,76.0,51.0,90.0,8.2,853.0,126.0,20.0,1.9,0.81,0.84,10.0,0.090,0.29,19.0,68.0,108.0,"Medium-heavy flex tank with dependable armor and punch.")
    tank_catalog["Sherman"] = TankData.build("Sherman",30.3,400.0,40.0,7.0,51.0,38.0,38.0,75.0,5.8,792.0,92.0,30.0,1.4,0.96,0.83,6.8,0.075,0.30,26.0,62.0,98.0,"Fast support medium. Wins through movement, tempo and flanking.")
    tank_catalog["StuG III"] = TankData.build("StuG III",24.0,300.0,40.0,7.0,80.0,30.0,30.0,75.0,5.0,925.0,120.0,0.0,1.6,0.90,0.85,6.8,0.075,0.29,27.0,64.0,96.0,"Assault gun. Low profile, excellent frontal plate, zero turret traverse.")
    tank_catalog["T-34"] = TankData.build("T-34",30.9,500.0,53.0,7.0,47.0,45.0,45.0,76.2,5.7,680.0,94.0,34.0,1.5,1.04,0.81,6.8,0.076,0.31,30.0,70.0,104.0,"Speed demon. The best tool in the roster for rapid flanks and disengages.")
    tank_catalog["Tiger"] = TankData.build("Tiger",56.9,650.0,38.0,8.0,100.0,82.0,82.0,88.0,8.2,773.0,148.0,28.0,1.9,0.71,0.88,10.0,0.088,0.29,17.0,66.0,112.0,"Heavy hunter. Accurate 88 mm gun and forgiving side armor.")
    tank_catalog["Tiger II"] = TankData.build("Tiger II",69.8,800.0,38.0,5.0,150.0,80.0,80.0,88.0,10.5,1000.0,165.0,22.0,2.2,0.63,0.90,10.0,0.088,0.27,14.0,70.0,128.0,"Endgame fortress. Massive frontal protection with a lethal high-velocity gun.")

    tank_catalog["Churchill"].role = "HEAVY"; tank_catalog["Churchill"].doctrine = "WALL"; tank_catalog["Churchill"].passive_name = "Fortified"; tank_catalog["Churchill"].passive_value = 0.82
    tank_catalog["Hetzer"].role = "DESTROYER"; tank_catalog["Hetzer"].doctrine = "AMBUSH"; tank_catalog["Hetzer"].passive_name = "Low Profile"; tank_catalog["Hetzer"].passive_value = 0.68
    tank_catalog["IS-2"].role = "HEAVY"; tank_catalog["IS-2"].doctrine = "BREACH"; tank_catalog["IS-2"].passive_name = "Devastation"; tank_catalog["IS-2"].passive_value = 1.22
    tank_catalog["KV-1"].role = "HEAVY"; tank_catalog["KV-1"].doctrine = "WALL"; tank_catalog["KV-1"].passive_name = "Old Armor"; tank_catalog["KV-1"].passive_value = 0.88
    tank_catalog["Panther"].role = "MEDIUM"; tank_catalog["Panther"].doctrine = "SNIPER"; tank_catalog["Panther"].passive_name = "Precision"; tank_catalog["Panther"].passive_value = 0.78
    tank_catalog["Panzer IV"].role = "MEDIUM"; tank_catalog["Panzer IV"].doctrine = "GENERALIST"; tank_catalog["Panzer IV"].passive_name = "Reliable"; tank_catalog["Panzer IV"].passive_value = 0.92
    tank_catalog["Pershing"].role = "MEDIUM"; tank_catalog["Pershing"].doctrine = "FLEX"; tank_catalog["Pershing"].passive_name = "Stabilized"; tank_catalog["Pershing"].passive_value = 0.86
    tank_catalog["Sherman"].role = "MEDIUM"; tank_catalog["Sherman"].doctrine = "FLANK"; tank_catalog["Sherman"].passive_name = "Momentum"; tank_catalog["Sherman"].passive_value = 1.10
    tank_catalog["StuG III"].role = "DESTROYER"; tank_catalog["StuG III"].doctrine = "AMBUSH"; tank_catalog["StuG III"].passive_name = "Hull Down"; tank_catalog["StuG III"].passive_value = 0.72
    tank_catalog["T-34"].role = "MEDIUM"; tank_catalog["T-34"].doctrine = "FLANK"; tank_catalog["T-34"].passive_name = "Agile"; tank_catalog["T-34"].passive_value = 1.18
    tank_catalog["Tiger"].role = "HEAVY"; tank_catalog["Tiger"].doctrine = "HUNTER"; tank_catalog["Tiger"].passive_name = "Veteran Optics"; tank_catalog["Tiger"].passive_value = 0.84
    tank_catalog["Tiger II"].role = "HEAVY"; tank_catalog["Tiger II"].doctrine = "BOSS"; tank_catalog["Tiger II"].passive_name = "Citadel"; tank_catalog["Tiger II"].passive_value = 0.70

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
    var p: Dictionary = {"hull_shape":Vector3(3.0,1.2,5.0),"turret_shape":"cylinder","turret_radius":1.15,"turret_height":0.65,"barrel_length":3.6,"hull_yaw":0.0,"turret_scale":Vector3.ONE,"hull_scale":Vector3.ONE,"barrel_scale":Vector3.ONE,"turret_visible":true,"color":Color("465044"),"accent":Color("2b302c")}
    match tank_name:
        "Churchill":
            p.hull_shape=Vector3(3.3,1.45,5.4); p.hull_scale=Vector3(1.08,1.08,1.05); p.turret_radius=1.28; p.turret_height=0.72; p.barrel_length=3.4; p.color=Color("4e5749")
        "Hetzer":
            p.hull_shape=Vector3(2.65,0.92,4.5); p.hull_scale=Vector3(0.94,0.80,1.02); p.turret_visible=false; p.barrel_length=4.0; p.color=Color("58604c")
        "IS-2":
            p.hull_shape=Vector3(3.25,1.32,5.25); p.turret_radius=1.30; p.turret_height=0.76; p.barrel_length=4.35; p.barrel_scale=Vector3(1.25,1.25,1.1); p.color=Color("4e544c")
        "KV-1":
            p.hull_shape=Vector3(3.35,1.42,5.35); p.turret_radius=1.34; p.turret_height=0.70; p.color=Color("505848")
        "Panther":
            p.hull_shape=Vector3(3.0,1.10,5.35); p.hull_scale=Vector3(1.06,0.98,1.08); p.turret_radius=1.15; p.turret_height=0.62; p.barrel_length=4.05; p.color=Color("4a5145")
        "Panzer IV":
            p.hull_shape=Vector3(2.9,1.15,5.0); p.turret_radius=1.10; p.turret_height=0.64; p.color=Color("56594d")
        "Pershing":
            p.hull_shape=Vector3(3.15,1.22,5.15); p.turret_radius=1.28; p.turret_height=0.70; p.barrel_length=4.0; p.color=Color("4c5549")
        "Sherman":
            p.hull_shape=Vector3(3.0,1.12,4.95); p.hull_scale=Vector3(1.02,0.98,1.02); p.turret_radius=1.20; p.turret_height=0.66; p.barrel_length=3.7; p.color=Color("5b5b47")
        "StuG III":
            p.hull_shape=Vector3(2.72,0.92,4.72); p.hull_scale=Vector3(0.96,0.78,1.05); p.turret_visible=false; p.barrel_length=4.0; p.color=Color("525847")
        "T-34":
            p.hull_shape=Vector3(2.88,1.00,5.05); p.hull_scale=Vector3(1.0,0.92,1.06); p.turret_radius=1.08; p.turret_height=0.58; p.barrel_length=3.55; p.color=Color("536047")
        "Tiger":
            p.hull_shape=Vector3(3.35,1.34,5.55); p.turret_radius=1.30; p.turret_height=0.72; p.barrel_length=4.15; p.color=Color("4a4d42")
        "Tiger II":
            p.hull_shape=Vector3(3.55,1.45,5.85); p.hull_scale=Vector3(1.10,1.06,1.10); p.turret_radius=1.42; p.turret_height=0.82; p.barrel_length=4.75; p.color=Color("505247")
    return p

func build_hull_mesh(profile: Dictionary) -> BoxMesh:
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = profile.get("hull_shape", Vector3(3.0,1.2,5.0))
    return mesh

func build_turret_mesh(profile: Dictionary) -> CylinderMesh:
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = profile.get("turret_radius",1.15)
    mesh.bottom_radius = profile.get("turret_radius",1.15)
    mesh.height = profile.get("turret_height",0.65)
    mesh.radial_segments = 14
    return mesh

func build_barrel_mesh(profile: Dictionary) -> CylinderMesh:
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = 0.105
    mesh.bottom_radius = 0.15
    mesh.height = profile.get("barrel_length",3.6)
    mesh.radial_segments = 10
    mesh.rotation_degrees = Vector3(90,0,0)
    return mesh

func spawn_tank(tank_name: String, position: Vector3, player_controlled: bool) -> TankBase:
    var data: TankData = tank_catalog.get(tank_name) as TankData
    if data == null:
        return null
    var tank: TankBase = TANK_SCENE.instantiate() as TankBase
    if tank == null:
        return null
    get_tree().current_scene.add_child(tank)
    tank.global_position = position
    tank.configure(data, player_controlled)
    return tank

func start_campaign() -> TankBase:
    end_match()
    campaign_wave = 0
    kills = 0
    score = 0
    match_elapsed = 0.0
    difficulty = 1.0
    player_tank = spawn_tank(selected_tank_name, Vector3(0,0,26), true)
    if player_tank == null:
        return null
    player_tank.name = "PlayerTank"
    player_tank.tank_destroyed.connect(_on_player_destroyed)
    match_active = true
    _start_next_wave()
    player_tank_changed.emit(player_tank)
    return player_tank

func _start_next_wave() -> void:
    campaign_wave += 1
    if campaign_wave > wave_total:
        match_active = false
        match_ended.emit(true)
        return
    difficulty = 0.92 + float(campaign_wave) * 0.18 + float(level - 1) * 0.03
    for bot: TankBase in bot_tanks:
        if is_instance_valid(bot):
            bot.queue_free()
    bot_tanks.clear()
    objective = WAVE_INFO[campaign_wave - 1]["objective"]
    var enemy_names: Array = WAVE_INFO[campaign_wave - 1]["enemies"]
    for i: int in range(enemy_names.size()):
        var angle: float = -1.15 + float(i) * 0.58
        var radius: float = 34.0 + float(campaign_wave) * 3.0
        var pos := Vector3(cos(angle) * radius, 0.0, -18.0 + sin(angle) * 22.0 - float(i % 2) * 6.0)
        var bot := spawn_tank(enemy_names[i], pos, false)
        if bot == null:
            continue
        bot.name = "Enemy_%02d_W%02d" % [i, campaign_wave]
        bot.bot_difficulty = difficulty
        bot.tank_destroyed.connect(_on_bot_destroyed.bind(bot))
        bot_tanks.append(bot)
    match_active = true
    intermission_remaining = 0.0
    wave_started.emit(campaign_wave, objective)
    feed_message.emit("WAVE %d: %s — %s" % [campaign_wave, WAVE_INFO[campaign_wave-1]["name"], objective])
    match_started.emit(player_tank, bot_tanks)

func _on_player_destroyed() -> void:
    if not match_active:
        return
    match_active = false
    match_ended.emit(false)

func _on_bot_destroyed(bot: TankBase) -> void:
    kills += 1
    var reward: int = 100 + campaign_wave * 50
    if bot != null and bot.tank_data != null and bot.tank_data.role == "HEAVY":
        reward += 75
    score += reward
    xp += reward
    credits += reward / 2
    mastery[selected_tank_name] = int(mastery.get(selected_tank_name,0)) + reward
    _check_level_up()
    feed_message.emit("DESTROYED %s  +%d XP  +%d CR" % [bot.tank_data.tank_name.to_upper(), reward, reward/2])
    if match_active:
        var survivors: int = 0
        for enemy: TankBase in bot_tanks:
            if is_instance_valid(enemy) and not enemy.destroyed:
                survivors += 1
        if survivors == 0:
            _complete_wave()

func _complete_wave() -> void:
    match_active = false
    var reward: int = int(WAVE_INFO[campaign_wave - 1]["reward"] * difficulty)
    score += reward
    xp += reward
    credits += reward
    _check_level_up()
    feed_message.emit("OBJECTIVE COMPLETE  +%d XP  +%d CR" % [reward, reward])
    if campaign_wave >= wave_total:
        match_ended.emit(true)
        return
    intermission_remaining = 5.0
    feed_message.emit("NEXT WAVE IN 5s — REPAIR AND REPOSITION")

func _check_level_up() -> void:
    var next_threshold: int = 1000 + (level - 1) * 650
    while xp >= next_threshold:
        xp -= next_threshold
        level += 1
        credits += 500
        feed_message.emit("RANK UP! COMMAND LEVEL %d  +500 CR" % level)
        next_threshold = 1000 + (level - 1) * 650
    progression_changed.emit()

func can_use_tank(tank_name: String) -> bool:
    var index: int = TANK_ORDER.find(tank_name)
    if index < 0:
        return false
    return level >= (1 + int(floor(float(index) / 3.0)))

func end_match() -> void:
    match_active = false
    intermission_remaining = 0.0
    if is_instance_valid(player_tank):
        player_tank.queue_free()
    player_tank = null
    for bot: TankBase in bot_tanks:
        if is_instance_valid(bot):
            bot.queue_free()
    bot_tanks.clear()

func find_nearest_enemy(source: TankBase) -> TankBase:
    if source == null:
        return null
    var best: TankBase
    var best_distance: float = INF
    if source.is_player:
        for bot: TankBase in bot_tanks:
            if is_instance_valid(bot) and not bot.destroyed:
                var d := source.global_position.distance_squared_to(bot.global_position)
                if d < best_distance:
                    best_distance = d
                    best = bot
    else:
        if is_instance_valid(player_tank) and not player_tank.destroyed:
            best = player_tank
    return best
