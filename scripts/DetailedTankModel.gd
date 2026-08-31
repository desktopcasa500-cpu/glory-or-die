class_name DetailedTankModel
extends Node3D

const DETAIL_COUNT: int = 240
const CUBE_SIZE: Vector3 = Vector3(0.16, 0.12, 0.16)

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

    var multimesh: MultiMesh = MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.instance_count = DETAIL_COUNT
    multimesh.visible_instance_count = DETAIL_COUNT

    var cube: BoxMesh = BoxMesh.new()
    cube.size = CUBE_SIZE
    cube.material = _detail_material(tank.tank_data.tank_name)
    multimesh.mesh = cube
    detail_instance.multimesh = multimesh
    add_child(detail_instance)

    var profile: Dictionary = GameState.get_visual_profile(tank.tank_data.tank_name)
    var hull: Vector3 = profile.get("hull_shape", Vector3(3.0, 1.2, 5.0))
    var name_value: String = tank.tank_data.tank_name

    for index: int in range(DETAIL_COUNT):
        multimesh.set_instance_transform(index, _make_transform(index, hull, name_value))

func _make_transform(index: int, hull: Vector3, name_value: String) -> Transform3D:
    var group: int = index % 8
    var band: int = index / 8
    var hx: float = hull.x * 0.5
    var hz: float = hull.z * 0.5
    var x: float = 0.0
    var y: float = 0.0
    var z: float = 0.0
    var scale: Vector3 = Vector3.ONE

    if group == 0:
        x = -hx * 0.94
        z = _spread(band, hz * 0.90)
        y = 0.30 + _noise(band, 0.08)
        scale = Vector3(1.1, 0.8, 2.0)
    elif group == 1:
        x = hx * 0.94
        z = _spread(band, hz * 0.90)
        y = 0.30 + _noise(band + 20, 0.08)
        scale = Vector3(1.1, 0.8, 2.0)
    elif group == 2:
        x = _spread(band, hx * 0.90)
        z = -hz * 0.94
        y = 0.42 + _noise(band + 40, 0.07)
        scale = Vector3(1.8, 0.7, 0.8)
    elif group == 3:
        x = _spread(band, hx * 0.90)
        z = hz * 0.94
        y = 0.42 + _noise(band + 60, 0.07)
        scale = Vector3(1.8, 0.7, 0.8)
    elif group == 4:
        x = _spread(band + 90, hx * 0.72)
        z = _noise(band + 100, hz * 0.72)
        y = hull.y * 0.5 + 0.76 + _noise(band + 120, 0.10)
        scale = Vector3(1.2, 0.65, 1.2)
    elif group == 5:
        var side: float = -1.0 if (band % 2) == 0 else 1.0
        x = side * hx * 1.04
        z = _spread(band + 130, hz * 0.76)
        y = 0.08 + _noise(band + 140, 0.06)
        scale = Vector3(2.4, 1.4, 0.55)
    elif group == 6:
        x = _spread(band + 160, hx * 0.65)
        z = _noise(band + 170, hz * 0.65)
        y = hull.y * 0.5 + 0.94 + _noise(band + 180, 0.08)
        scale = Vector3(0.8, 1.5, 0.8)
    else:
        x = _spread(band + 200, hx * 0.78)
        z = _noise(band + 210, hz * 0.78)
        y = 0.72 + _noise(band + 220, 0.08)
        scale = Vector3(0.7, 0.7, 1.7)

    if name_value == "Hetzer" or name_value == "StuG III":
        y -= 0.12
        scale.y *= 0.75
    elif name_value == "Tiger II":
        scale *= 1.14
    elif name_value == "Tiger":
        scale *= 1.08
    elif name_value == "T-34" or name_value == "Sherman":
        scale *= 1.04

    var basis: Basis = Basis.IDENTITY.scaled(scale)
    basis = basis.rotated(Vector3.UP, _noise(index + 700, 0.20))
    return Transform3D(basis, Vector3(x, y, z))

func _spread(value: int, extent: float) -> float:
    var t: float = float(value % 30) / 29.0
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
    else:
        material.albedo_color = Color("323a31")
    return material
