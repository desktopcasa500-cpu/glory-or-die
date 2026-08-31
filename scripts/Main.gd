extends Node3D

var player: TankBase
var camera: Camera3D
var hud: CombatHUD
var arena_root: Node3D
var camera_shake: float = 0.0
var camera_base: Vector3

func _ready() -> void:
    RenderingServer.set_default_clear_color(Color("080b0e"))
    _build_environment()
    _build_arena()
    _build_camera()
    _build_hud()
    player = GameState.start_campaign()
    hud.bind_tank(player)
    player.fired.connect(_on_player_fired)
    player.combat_event.connect(_on_combat_event)

func _process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    if is_instance_valid(camera):
        var target := player.global_position + player.global_transform.basis * Vector3(0.0, 4.8, 10.5)
        target.y = player.global_position.y + 4.8
        camera.global_position = camera.global_position.lerp(target, minf(1.0, delta * 5.0))
        if camera_shake > 0.0:
            camera_shake = maxf(0.0, camera_shake - delta)
            camera.global_position += Vector3(randf_range(-0.08,0.08),randf_range(-0.05,0.05),randf_range(-0.08,0.08)) * (camera_shake * 5.0)
        camera.look_at(player.global_position + Vector3(0,1.0,0), Vector3.UP)

func _build_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("080b0e")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("6b726d")
    env.ambient_light_energy = 0.68
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 1.08
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55,-28,0)
    sun.light_energy = 1.15
    sun.shadow_enabled = true
    add_child(sun)

func _build_arena() -> void:
    arena_root = Node3D.new()
    arena_root.name = "Arena"
    add_child(arena_root)
    var ground := StaticBody3D.new()
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(180,1,180)
    collision.shape = shape
    collision.position.y = -0.5
    ground.add_child(collision)
    var mesh := MeshInstance3D.new()
    var ground_mesh := BoxMesh.new()
    ground_mesh.size = Vector3(180,1,180)
    mesh.mesh = ground_mesh
    mesh.position.y = -0.5
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("333934")
    material.roughness = 1.0
    mesh.material_override = material
    ground.add_child(mesh)
    arena_root.add_child(ground)
    var covers: Array[Vector3] = [Vector3(-45,1,-20),Vector3(45,1,-20),Vector3(-18,1,-44),Vector3(25,1,-48),Vector3(0,1,-65),Vector3(-55,1,-60),Vector3(52,1,-58),Vector3(0,1,-27)]
    for p in covers:
        _add_cover_block(p)
    _add_objective_beacon(Vector3(0,0,-46))

func _add_cover_block(position: Vector3) -> void:
    var body := StaticBody3D.new()
    body.position = position
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(7,2.2,4)
    collision.shape = shape
    collision.rotation_degrees.y = 22
    body.add_child(collision)
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(7,2.2,4)
    mesh.mesh = box
    mesh.rotation_degrees.y = 22
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("4b514c")
    mat.roughness = 0.98
    mesh.material_override = mat
    body.add_child(mesh)
    arena_root.add_child(body)

func _add_objective_beacon(position: Vector3) -> void:
    var beacon := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 1.7
    cylinder.bottom_radius = 1.7
    cylinder.height = 0.25
    beacon.mesh = cylinder
    beacon.position = position
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("b46a32")
    mat.emission_enabled = true
    mat.emission = Color("6b3514")
    mat.emission_energy_multiplier = 2.0
    beacon.material_override = mat
    arena_root.add_child(beacon)

func _build_camera() -> void:
    camera = Camera3D.new()
    camera.fov = 62.0
    camera.current = true
    add_child(camera)
    camera.global_position = Vector3(0,6,36)
    camera_base = camera.global_position

func _build_hud() -> void:
    hud = CombatHUD.new()
    add_child(hud)

func _on_player_fired(_projectile: Projectile) -> void:
    camera_shake = 0.16

func _on_combat_event(text: String) -> void:
    hud.push_feed(text)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_G:
                hud.toggle_garage()
            KEY_X:
                hud.toggle_xray()
            KEY_ENTER:
                if not GameState.match_active and GameState.campaign_wave >= GameState.wave_total:
                    player = GameState.start_campaign()
                    hud.bind_tank(player)
                    hud.close_overlays()
            KEY_ESCAPE:
                hud.toggle_pause()
