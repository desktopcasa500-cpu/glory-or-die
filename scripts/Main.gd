extends Node3D

var player: TankBase
var camera: Camera3D
var xray_panel: XRayPanel
var game_over_label: Label

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0b0f13"))
	_build_world()
	player = GameState.start_match(Vector3.ZERO)
	var hud: CombatHUD = CombatHUD.new()
	hud.name = "CombatHUD"
	add_child(hud)
	hud.bind_tank(player)
	xray_panel = XRayPanel.new()
	xray_panel.name = "XRayPanel"
	xray_panel.position = Vector2(860.0, 390.0)
	xray_panel.size = Vector2(400.0, 300.0)
	xray_panel.visible = false
	hud.add_child(xray_panel)
	xray_panel.bind_tank(player)
	game_over_label = Label.new()
	game_over_label.position = Vector2(465.0, 330.0)
	game_over_label.add_theme_font_size_override("font_size", 32)
	game_over_label.visible = false
	hud.add_child(game_over_label)
	GameState.match_ended.connect(_on_match_ended)

func _build_world() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b0f13")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8d949b")
	environment.ambient_light_energy = 0.55
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	add_child(sun)
	var ground: StaticBody3D = StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 1 | 2
	var ground_shape: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(220.0, 0.4, 220.0)
	ground_shape.shape = shape
	ground_shape.position.y = -0.2
	ground.add_child(ground_shape)
	var ground_mesh: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(220.0, 0.4, 220.0)
	ground_mesh.mesh = mesh
	ground_mesh.position.y = -0.2
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("343b35")
	material.roughness = 1.0
	ground_mesh.material_override = material
	ground.add_child(ground_mesh)
	add_child(ground)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 62.0
	add_child(camera)

func _process(_delta: float) -> void:
	if is_instance_valid(player) and not player.destroyed:
		var target: Vector3 = player.global_position + Vector3(0.0, 5.2, 8.5)
		camera.global_position = camera.global_position.lerp(target, 0.08)
		camera.look_at(player.global_position + Vector3(0.0, 1.1, 0.0), Vector3.UP)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("xray"):
		xray_panel.visible = not xray_panel.visible

func _on_match_ended(player_won: bool) -> void:
	game_over_label.text = "VICTORY" if player_won else "VEHICLE DESTROYED"
	game_over_label.visible = true

func _exit_tree() -> void:
	if GameState.match_active:
		GameState.end_match()
