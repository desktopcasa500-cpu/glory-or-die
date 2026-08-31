extends Node3D

var player: TankBase
var camera: Camera3D
var hud: CombatHUD
var arena_root: Node3D
var camera_shake: float = 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    RenderingServer.set_default_clear_color(Color("080b0e"))
    GameState.player_tank_changed.connect(_on_player_tank_changed)
    _build_environment()
    _build_arena()
    _build_camera()
    _build_hud()
    var initial_player: TankBase = GameState.start_campaign()
    _on_player_tank_changed(initial_player)

func _process(delta: float) -> void:
    if not is_instance_valid(player) or not is_instance_valid(camera):
        return
    var desired_camera: Vector3 = player.global_position + player.global_transform.basis * Vector3(0.0, 4.8, 10.5)
    desired_camera.y = player.global_position.y + 4.8
    camera.global_position = camera.global_position.lerp(desired_camera, minf(1.0, delta * 5.0))
    if camera_shake > 0.0:
        camera_shake = maxf(0.0, camera_shake - delta)
        var shake: Vector3 = Vector3(randf_range(-0.08, 0.08), randf_range(-0.05, 0.05), randf_range(-0.08, 0.08))
        camera.global_position += shake * (camera_shake * 5.0)
    camera.look_at(player.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)

func _on_player_tank_changed(new_player: TankBase) -> void:
    player = new_player
    if not is_instance_valid(player):
        return
    if is_instance_valid(hud):
        hud.bind_tank(player)
    if not player.fired.is_connected(_on_player_fired):
        player.fired.connect(_on_player_fired)

func _build_environment() -> void:
    var world: WorldEnvironment = WorldEnvironment.new()
    var environment: Environment = Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("080b0e")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("6b726d")
    environment.ambient_light_energy = 0.68
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.tonemap_exposure = 1.08
    world.environment = environment
    add_child(world)
    var sun: DirectionalLight3D = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55.0, -28.0, 0.0)
    sun.light_energy = 1.15
    sun.shadow_enabled = false
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
    material.albedo_color = Color("333934")
    material.roughness = 1.0
    mesh.material_override = material
    ground.add_child(mesh)
    arena_root.add_child(ground)
    var covers: Array[Vector3] = [Vector3(-45.0, 1.0, -20.0), Vector3(45.0, 1.0, -20.0), Vector3(-18.0, 1.0, -44.0), Vector3(25.0, 1.0, -48.0), Vector3(0.0, 1.0, -65.0), Vector3(-55.0, 1.0, -60.0), Vector3(52.0, 1.0, -58.0), Vector3(0.0, 1.0, -27.0)]
    for cover_position: Vector3 in covers:
        _add_cover_block(cover_position)
    _add_objective_beacon(Vector3(0.0, 0.0, -46.0))

func _add_cover_block(position_value: Vector3) -> void:
    var body: StaticBody3D = StaticBody3D.new()
    body.position = position_value
    var collision: CollisionShape3D = CollisionShape3D.new()
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = Vector3(7.0, 2.2, 4.0)
    collision.shape = shape
    collision.rotation_degrees.y = 22.0
    body.add_child(collision)
    var mesh: MeshInstance3D = MeshInstance3D.new()
    var box: BoxMesh = BoxMesh.new()
    box.size = Vector3(7.0, 2.2, 4.0)
    mesh.mesh = box
    mesh.rotation_degrees.y = 22.0
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color("4b514c")
    material.roughness = 0.98
    mesh.material_override = material
    body.add_child(mesh)
    arena_root.add_child(body)

func _add_objective_beacon(position_value: Vector3) -> void:
    var beacon: MeshInstance3D = MeshInstance3D.new()
    var cylinder: CylinderMesh = CylinderMesh.new()
    cylinder.top_radius = 1.7
    cylinder.bottom_radius = 1.7
    cylinder.height = 0.25
    cylinder.radial_segments = 16
    beacon.mesh = cylinder
    beacon.position = position_value
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color("b46a32")
    material.emission_enabled = true
    material.emission = Color("6b3514")
    material.emission_energy_multiplier = 1.7
    beacon.material_override = material
    arena_root.add_child(beacon)

func _build_camera() -> void:
    camera = Camera3D.new()
    camera.fov = 62.0
    camera.current = true
    add_child(camera)
    camera.global_position = Vector3(0.0, 6.0, 36.0)

func _build_hud() -> void:
    hud = CombatHUD.new()
    add_child(hud)

func _on_player_fired(_projectile: Projectile) -> void:
    camera_shake = 0.16

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event: InputEventKey = event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    if key_event.keycode == KEY_G:
        hud.toggle_garage()
    elif key_event.keycode == KEY_X:
        hud.toggle_xray()
    elif key_event.keycode == KEY_ENTER:
        if not GameState.match_active and GameState.campaign_wave >= GameState.wave_total:
            var restarted: TankBase = GameState.start_campaign()
            _on_player_tank_changed(restarted)
            hud.close_overlays()
    elif key_event.keycode == KEY_ESCAPE:
        hud.toggle_pause()

func _exit_tree() -> void:
    if GameState.player_tank_changed.is_connected(_on_player_tank_changed):
        GameState.player_tank_changed.disconnect(_on_player_tank_changed)
