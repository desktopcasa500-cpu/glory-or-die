extends Node3D

var player: TankBase

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("101214"))
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101214")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6f7378")
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -25.0, 0.0)
	sun.light_energy = 1.0
	add_child(sun)
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0.0, 5.5, 9.0)
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	camera.current = true
	add_child(camera)
	player = GameState.start_match(Vector3.ZERO) as TankBase
	var hud: CombatHUD = CombatHUD.new()
	add_child(hud)
	hud.bind_tank(player)
	var xray: XRayPanel = XRayPanel.new()
	xray.position = Vector2(0.0, 400.0)
	xray.size = Vector2(400.0, 280.0)
	xray.visible = false
	hud.add_child(xray)
	xray.bind_tank(player)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_X and player != null:
		var panel: XRayPanel = get_node("CombatHUD/XRayPanel") as XRayPanel
		panel.visible = not panel.visible

func _exit_tree() -> void:
	if is_instance_valid(GameState):
		GameState.stop_match()
