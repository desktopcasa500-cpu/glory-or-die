extends Node

signal vehicle_selected(data: TankData)
signal player_spawned(tank: Node3D)
signal match_state_changed(active: bool)

var selected_tank: TankData
var player_tank: Node3D
var bot_tanks: Array[Node3D] = []
var match_active: bool = false

func _ready() -> void:
	selected_tank = get_tank_data("Sherman")

func select_tank(tank_name: String) -> void:
	selected_tank = get_tank_data(tank_name)
	vehicle_selected.emit(selected_tank)

func get_tank_data(tank_name: String) -> TankData:
	var tanks: Dictionary = _tank_catalog()
	return tanks.get(tank_name, tanks["Sherman"]) as TankData

func get_all_tanks() -> Array[TankData]:
	var result: Array[TankData] = []
	for value: Variant in _tank_catalog().values():
		result.append(value as TankData)
	return result

func start_match(spawn_position: Vector3 = Vector3.ZERO) -> Node3D:
	if player_tank != null and is_instance_valid(player_tank):
		player_tank.queue_free()
	var scene: PackedScene = load("res://scenes/TankBase.tscn") as PackedScene
	player_tank = scene.instantiate() as Node3D
	get_tree().current_scene.add_child(player_tank)
	player_tank.position = spawn_position
	player_tank.call("configure", selected_tank, true)
	match_active = true
	match_state_changed.emit(true)
	player_spawned.emit(player_tank)
	return player_tank

func stop_match() -> void:
	match_active = false
	match_state_changed.emit(false)
	if player_tank != null and is_instance_valid(player_tank):
		player_tank.queue_free()
	player_tank = null
	for bot: Node3D in bot_tanks:
		if is_instance_valid(bot):
			bot.queue_free()
	bot_tanks.clear()

func _tank_catalog() -> Dictionary:
	return {
		"Churchill": TankData.create("Churchill",39.0,350.0,25.0,4.0,89.0,76.0,51.0,75.0,5.2,615.0,95.0,18.0,2.7,0.68),
		"Hetzer": TankData.create("Hetzer",16.0,150.0,42.0,6.0,60.0,20.0,20.0,75.0,7.0,925.0,130.0,0.0,2.2,0.92),
		"IS2": TankData.create("IS-2",46.0,390.0,37.0,7.0,100.0,90.0,60.0,122.0,25.0,800.0,160.0,12.0,3.8,0.63),
		"KV1": TankData.create("KV-1",45.0,330.0,34.0,5.0,75.0,70.0,70.0,76.2,9.0,680.0,90.0,14.0,3.0,0.65),
		"Panther": TankData.create("Panther",44.8,350.0,46.0,4.0,80.0,50.0,40.0,75.0,7.5,935.0,138.0,14.0,2.4,0.84),
		"PanzerIV": TankData.create("Panzer IV",25.0,210.0,38.0,6.0,80.0,30.0,20.0,75.0,6.0,740.0,91.0,14.0,2.3,0.88),
		"Pershing": TankData.create("M26 Pershing",41.7,340.0,40.0,5.0,102.0,76.0,51.0,90.0,8.5,853.0,130.0,15.0,2.7,0.76),
		"Sherman": TankData.create("M4 Sherman",30.3,240.0,48.0,5.0,63.0,38.0,38.0,75.0,5.0,619.0,88.0,24.0,2.1,0.96),
		"StuG": TankData.create("StuG III",23.9,220.0,40.0,6.0,80.0,30.0,30.0,75.0,6.0,770.0,100.0,0.0,2.0,0.87),
		"T34": TankData.create("T-34",26.5,230.0,55.0,8.0,45.0,40.0,40.0,76.2,5.8,680.0,86.0,20.0,2.0,1.0),
		"Tiger": TankData.create("Tiger I",54.0,430.0,45.0,8.0,100.0,82.0,82.0,88.0,8.5,773.0,138.0,15.0,2.7,0.72),
		"Tiger2": TankData.create("Tiger II",69.8,520.0,38.0,7.0,150.0,80.0,80.0,88.0,10.0,1000.0,180.0,12.0,3.0,0.58)
	}
