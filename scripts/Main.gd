extends Node3D

var player: Node3D

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
	player = GameState.start_match(Vector3.ZERO)
	var hud: CanvasLayer = CanvasLayer.new()
	var label: Label = Label.new()
	label.position = Vector2(24.0, 22.0)
	label.text = "GLORY OR DIE\nWASD — movimento    Q/E — torre    Mouse — disparo    F — reparo"
	label.add_theme_font_size_override("font_size", 18)
	hud.add_child(label)
	add_child(hud)

func _exit_tree() -> void:
	if is_instance_valid(GameState):
		GameState.stop_match()
