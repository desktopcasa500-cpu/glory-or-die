class_name DetailedTankModel
extends Node3D

const DETAIL_COUNT: int = 240
const CUBE_SIZE: Vector3 = Vector3(0.16, 0.12, 0.16)
const DETAIL_AABB: AABB = AABB(Vector3(-5.0, -2.0, -7.0), Vector3(10.0, 6.0, 14.0))

var built: bool = false

func _process(_delta: float) -> void:
    if built:
        set_process(false)
        return
    var tank: TankBase = get_parent() as TankBase
    if tank == null or tank.tank_data == null:
        return
    _build(tank)
    built = true
    set_process(false)

func _build(tank: TankBase) -> void:
    var detail_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
    detail_instance.name = "DetailCubes_240"
    detail_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    detail_instance.custom_aabb = DETAIL_AABB

    var multimesh: MultiMesh = MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.instance_count = DETAIL_COUNT
    multimesh.visible_instance_count = DETAIL_COUNT

    var cube: BoxMesh = BoxMesh.new()
    cube.size = CUBE_SIZE
    multimesh.mesh = cube
    detail_instance.multimesh = multimesh
    detail_instance.material_override = _detail_material(tank.tank_data.tank_name)
    add_child(detail_instance)

    var profile: Dictionary = GameState.get_visual_profile(tank.tank_data.tank_name)
    var hull: Vector3 = profile.get("hull_shape", Vector3(3.0, 1.2, 5.0))
    var name_value: String = tank.tank_data.tank_name

    for index: int in range(DETAIL_COUNT):
        multimesh.set_instance_transform(index, _make_transform(index, hull, name_value))

func _make_transform(index: int, hull: Vector3, name_value: String) -> Transform3D:
    var variant: int = absi(name_value.hash()) % 97
    var group: int = (index + variant) % 8
    var band: int = index / 8
    var hx: float = hull.x * 0.5
    var hz: float = hull.z * 0.5
    var x: float = 0.0
    var y: float = 0.0
    var z: float = 0.0
    var scale: Vector3 = Vector3.ONE

    if group == 0:
        x = -hx * 0.94
        z = _spread(band + variant, hz * 0.90)
        y = 0.30 + _noise(band + variant, 0.08)
        scale = Vector3(1.1, 0.8, 2.0)
    elif group == 1:
        x = hx * 0.94
        z = _spread(band + variant, hz * 0.90)
        y = 0.30 + _noise(band + variant + 20, 0.08)
        scale = Vector3(1.1, 0.8, 2.0)
    elif group == 2:
        x = _spread(band + variant, hx * 0.90)
        z = -hz * 0.94
        y = 0.42 + _noise(band + variant + 40, 0.07)
        scale = Vector3(1.8, 0.7, 0.8)
    elif group == 3:
        x = _spread(band + variant, hx * 0.90)
        z = hz * 0.94
        y = 0.42 + _noise(band + variant + 60, 0.07)
        scale = Vector3(1.8, 0.7, 0.8)
    elif group == 4:
        x = _spread(band + variant + 90, hx * 0.72)
        z = _noise(band + variant + 100, hz * 0.72)
        y = hull.y * 0.5 + 0.76 + _noise(band + variant + 120, 0.10)
        scale = Vector3(1.2, 0.65, 1.2)
    elif group == 5:
        var side: float = -1.0 if ((band + variant) % 2) == 0 else 1.0
        x = side * hx * 1.04
        z = _spread(band + variant + 130, hz * 0.76)
        y = 0.08 + _noise(band + variant + 140, 0.06)
        scale = Vector3(2.4, 1.4, 0.55)
    elif group == 6:
        x = _spread(band + variant + 160, hx * 0.65)
        z = _noise(band + variant + 170, hz * 0.65)
        y = hull.y * 0.5 + 0.94 + _noise(band + variant + 180, 0.08)
        scale = Vector3(0.8, 1.5, 0.8)
    else:
        x = _spread(band + variant + 200, hx * 0.78)
        z = _noise(band + variant + 210, hz * 0.78)
        y = 0.72 + _noise(band + variant + 220, 0.08)
        scale = Vector3(0.7, 0.7, 1.7)

    if name_value == "Hetzer" or name_value == "StuG III":
        y -= 0.12
        scale.y *= 0.74
        if group == 4 or group == 6:
            scale.x *= 0.90
    elif name_value == "Tiger II":
        scale *= 1.14
    elif name_value == "Tiger":
        scale *= 1.08
    elif name_value == "T-34" or name_value == "Sherman":
        scale *= 1.04
    elif name_value == "Churchill" or name_value == "KV-1":
        scale.x *= 1.08
        scale.z *= 1.02
    elif name_value == "Panther":
        scale.z *= 1.08
    elif name_value == "IS-2":
        scale.y *= 1.05

    var rotation_amount: float = _noise(index + variant + 700, 0.20)
    var basis: Basis = Basis.IDENTITY.scaled(scale)
    basis = basis.rotated(Vector3.UP, rotation_amount)
    return Transform3D(basis, Vector3(x, y, z))

func _spread(value: int, extent: float) -> float:
    var t: float = float(posmod(value, 30)) / 29.0
    return lerpf(-extent, extent, t)

func _noise(value: int, amplitude: float) -> float:
    var raw: float = sin(float(value) * 12.9898) * 43758.5453
    var unit: float = raw - floor(raw)
    return (unit * 2.0 - 1.0) * amplitude

func _detail_material(name_value: String) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.roughness = 0.95
    if name_value == "Sherman" or name_value == "Pershing":
        material.albedo_color = Color("30392f")
    elif name_value == "T-34" or name_value == "KV-1" or name_value == "IS-2":
        material.albedo_color = Color("313a31")
    elif name_value == "Tiger" or name_value == "Tiger II" or name_value == "Panzer IV":
        material.albedo_color = Color("353930")
    elif name_value == "Hetzer" or name_value == "StuG III":
        material.albedo_color = Color("394038")
    else:
        material.albedo_color = Color("323a31")
    return material
