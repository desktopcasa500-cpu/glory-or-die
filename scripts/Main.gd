extends Node3D

var player: TankBase
var camera: Camera3D
var hud: CombatHUD
var arena_root: Node3D

func _ready() -> void:
    RenderingServer.set_default_clear_color(Color("0a0d10"))
    _build_environment()
    _build_arena()
    player = GameState.start_match(Vector3.ZERO)
    _build_camera()
    _build_hud()

func _process(_delta: float) -> void:
    if not is_instance_valid(player):
        return
    if is_instance_valid(camera):
        var target_position: Vector3 = player.global_position + Vector3(0.0, 3.8, 7.5)
        camera.global_position = camera.global_position.lerp(target_position, 0.08)
        camera.look_at(player.global_position + Vector3(0.0, 1.1, 0.0), Vector3.UP)

func _build_environment() -> void:
    var world: WorldEnvironment = WorldEnvironment.new()
    var environment: Environment = Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("0a0d10")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("777f86")
    environment.ambient_light_energy = 0.55
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.tonemap_exposure = 1.05
    world.environment = environment
    add_child(world)
    var sun: DirectionalLight3D = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52.0, -30.0, 0.0)
    sun.light_energy = 1.0
    sun.shadow_enabled = true
    add_child(sun)

func _build_arena() -> void:
    arena_root = Node3D.new()
    arena_root.name = "Arena"
    add_child(arena_root)
    var ground: StaticBody3D = StaticBody3D.new()
    var collision: CollisionShape3D = CollisionShape3D.new()
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = Vector3(180.0, 1.0, 180.0)
    collision.shape = shape
    collision.position.y = -0.5
    ground.add_child(collision)
    var mesh: MeshInstance3D = MeshInstance3D.new()
    var ground_mesh: BoxMesh = BoxMesh.new()
    ground_mesh.size = Vector3(180.0, 1.0, 180.0)
    mesh.mesh = ground_mesh
    mesh.position.y = -0.5
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color("343a36")
    material.roughness = 1.0
    mesh.material_override = material
    ground.add_child(mesh)
    arena_root.add_child(ground)
    var rock_positions: Array[Vector3] = [Vector3(-45.0, 1.0, -20.0), Vector3(45.0, 1.0, -20.0), Vector3(-18.0, 1.0, -42.0), Vector3(24.0, 1.0, -48.0), Vector3(0.0, 1.0, -65.0), Vector3(-56.0, 1.0, -58.0)]
    for p: Vector3 in rock_positions:
        _add_cover_block(p)

func _add_cover_block(position: Vector3) -> void:
    var body: StaticBody3D = StaticBody3D.new()
    body.position = position
    var collision: CollisionShape3D = CollisionShape3D.new()
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = Vector3(7.0, 2.0, 4.0)
    collision.shape = shape
    collision.rotation_degrees.y = 22.0
    body.add_child(collision)
    var mesh: MeshInstance3D = MeshInstance3D.new()
    var box: BoxMesh = BoxMesh.new()
    box.size = Vector3(7.0, 2.0, 4.0)
    mesh.mesh = box
    mesh.rotation_degrees.y = 22.0
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color("4b504c")
    material.roughness = 0.98
    mesh.material_override = material
    body.add_child(mesh)
    arena_root.add_child(body)

func _build_camera() -> void:
    camera = Camera3D.new()
    camera.fov = 60.0
    camera.current = true
    add_child(camera)
    camera.global_position = Vector3(0.0, 4.0, 17.0)

func _build_hud() -> void:
    hud = CombatHUD.new()
    add_child(hud)
    hud.bind_tank(player)
    var xray: XRayPanel = XRayPanel.new()
    xray.name = "XRayPanel"
    xray.position = Vector2(22.0, 420.0)
    xray.size = Vector2(420.0, 280.0)
    xray.visible = false
    hud.add_child(xray)
    xray.bind_tank(player)
    hud.set_xray_panel(xray)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_X and is_instance_valid(hud):
            hud.toggle_xray()
        elif event.keycode == KEY_R and is_instance_valid(hud):
            hud.toggle_garage()
        elif event.keycode == KEY_ESCAPE:
            get_tree().quit()

func _exit_tree() -> void:
    GameState.end_match()
