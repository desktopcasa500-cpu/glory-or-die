extends Node

signal player_tank_changed(tank: TankBase)
signal match_started(player: TankBase, enemies: Array[TankBase])
signal match_ended(player_won: bool)
signal projectile_impact(target: Node, hit_position: Vector3, hit_normal: Vector3, travel_direction: Vector3, penetration_mm: float, incidence_angle_deg: float)

const TANK_SCENE: PackedScene = preload("res://scenes/TankBase.tscn")

var selected_tank_name: String = "Panther"
var player_tank: TankBase
var bot_tanks: Array[TankBase] = []
var match_active: bool = false
var tank_catalog: Dictionary = {}

func _ready() -> void:
	_build_catalog()

func _build_catalog() -> void:
	tank_catalog.clear()
	tank_catalog["Churchill"] = TankData.build("Churchill", 38.5, 350.0, 24.0, 3.2, 102.0, 51.0, 51.0, 75.0, 5.5, 619.0, 82.0, 24.0, 2.4, 0.64, 0.79, 6.0, 0.076, 0.31)
	tank_catalog["Hetzer"] = TankData.build("Hetzer", 15.8, 160.0, 42.0, 7.0, 60.0, 20.0, 20.0, 75.0, 4.7, 925.0, 120.0, 0.0, 1.8, 0.92, 0.88, 6.8, 0.075, 0.29)
	tank_catalog["IS-2"] = TankData.build("IS-2", 46.0, 520.0, 37.0, 6.0, 100.0, 90.0, 60.0, 122.0, 19.5, 800.0, 180.0, 18.0, 3.2, 0.72, 0.83, 25.0, 0.122, 0.27)
	tank_catalog["KV-1"] = TankData.build("KV-1", 45.0, 500.0, 34.0, 5.0, 75.0, 70.0, 70.0, 76.2, 8.5, 680.0, 92.0, 18.0, 2.8, 0.69, 0.78, 6.8, 0.076, 0.31)
	tank_catalog["Panther"] = TankData.build("Panther", 44.8, 700.0, 46.0, 4.0, 80.0, 50.0, 40.0, 75.0, 7.0, 935.0, 138.0, 22.0, 1.7, 0.88, 0.86, 6.8, 0.075, 0.28)
	tank_catalog["Panzer IV"] = TankData.build("Panzer IV", 25.0, 300.0, 38.0, 8.0, 50.0, 30.0, 20.0, 75.0, 6.0, 740.0, 99.0, 25.0, 1.9, 0.87, 0.83, 6.8, 0.075, 0.30)
	tank_catalog["Pershing"] = TankData.build("Pershing", 41.7, 500.0, 40.0, 8.0, 102.0, 76.0, 51.0, 90.0, 8.2, 853.0, 126.0, 20.0, 2.0, 0.81, 0.84, 10.0, 0.090, 0.29)
	tank_catalog["Sherman"] = TankData.build("Sherman", 30.3, 400.0, 40.0, 7.0, 51.0, 38.0, 38.0, 75.0, 5.8, 792.0, 92.0, 30.0, 1.4, 0.96, 0.83, 6.8, 0.075, 0.30)
	tank_catalog["StuG III"] = TankData.build("StuG III", 24.0, 300.0, 40.0, 7.0, 80.0, 30.0, 30.0, 75.0, 5.0, 925.0, 120.0, 0.0, 1.6, 0.90, 0.85, 6.8, 0.075, 0.29)
	tank_catalog["T-34"] = TankData.build("T-34", 30.9, 500.0, 53.0, 7.0, 47.0, 45.0, 45.0, 76.2, 5.7, 680.0, 94.0, 34.0, 1.5, 1.04, 0.81, 6.8, 0.076, 0.31)
	tank_catalog["Tiger"] = TankData.build("Tiger", 56.9, 650.0, 38.0, 8.0, 100.0, 82.0, 82.0, 88.0, 8.2, 773.0, 148.0, 28.0, 1.9, 0.71, 0.88, 10.0, 0.088, 0.29)
	tank_catalog["Tiger II"] = TankData.build("Tiger II", 69.8, 800.0, 38.0, 5.0, 150.0, 80.0, 80.0, 88.0, 10.5, 1000.0, 165.0, 22.0, 2.2, 0.63, 0.90, 10.0, 0.088, 0.27)

func set_selected_tank(tank_name: String) -> bool:
	if not tank_catalog.has(tank_name):
		return false
	selected_tank_name = tank_name
	return true

func get_selected_data() -> TankData:
	return tank_catalog.get(selected_tank_name) as TankData

func get_tank_names() -> Array[String]:
	var names: Array[String] = []
	for key: Variant in tank_catalog.keys():
		names.append(str(key))
	return names

func spawn_tank(tank_name: String, position: Vector3, player_controlled: bool) -> TankBase:
	var data: TankData = tank_catalog.get(tank_name) as TankData
	var tank: TankBase = TANK_SCENE.instantiate() as TankBase
	tank.global_position = position
	get_tree().current_scene.add_child(tank)
	tank.configure(data, player_controlled)
	return tank

func start_match(origin: Vector3 = Vector3.ZERO) -> TankBase:
	end_match()
	player_tank = spawn_tank(selected_tank_name, origin + Vector3(0.0, 0.8, 7.0), true)
	player_tank.name = "PlayerTank"
	bot_tanks.clear()
	var names: Array[String] = get_tank_names()
	var spawn_index: int = 0
	for tank_name: String in names:
		if tank_name == selected_tank_name or spawn_index >= 4:
			continue
		var bot_position: Vector3 = origin + Vector3(float(spawn_index * 16 - 24), 0.8, -28.0 - float(spawn_index % 2) * 8.0)
		var bot: TankBase = spawn_tank(tank_name, bot_position, false)
		bot.name = "Bot_%02d_%s" % [spawn_index, tank_name.replace(" ", "_")]
		bot_tanks.append(bot)
		spawn_index += 1
	match_active = true
	player_tank_changed.emit(player_tank)
	match_started.emit(player_tank, bot_tanks)
	return player_tank

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
