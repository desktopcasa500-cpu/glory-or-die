class_name CombatHUD
extends CanvasLayer

var tank: TankBase
var status_label: Label
var reload_label: Label
var speed_label: Label
var ballistic_label: Label
var hint_label: Label
var last_repair_message: String = ""

func _ready() -> void:
	status_label = _make_label(Vector2(24.0, 20.0), 22)
	reload_label = _make_label(Vector2(24.0, 53.0), 16)
	speed_label = _make_label(Vector2(24.0, 79.0), 16)
	ballistic_label = _make_label(Vector2(24.0, 106.0), 14)
	hint_label = _make_label(Vector2(24.0, 672.0), 14)
	hint_label.text = "WASD movimento  |  Q/E torre  |  MOUSE disparo  |  F reparar  |  X raio-X"

func _make_label(position_value: Vector2, size_value: int) -> Label:
	var label: Label = Label.new()
	label.position = position_value
	label.add_theme_font_size_override("font_size", size_value)
	add_child(label)
	return label

func bind_tank(target: TankBase) -> void:
	tank = target
	tank.tank_destroyed.connect(_on_destroyed)
	tank.repair_started.connect(_on_repair_started)
	tank.repair_finished.connect(_on_repair_finished)

func _process(_delta: float) -> void:
	if not is_instance_valid(tank) or tank.tank_data == null:
		return
	status_label.text = "%s   |   HULL %d%%" % [tank.tank_data.tank_name.to_upper(), roundi(tank.hull_health)]
	reload_label.text = "RELOAD  %.1fs" % tank.reload_remaining if tank.reload_remaining > 0.0 else "READY"
	speed_label.text = "SPEED  %d km/h   |   ENGINE %s" % [roundi(tank.velocity.length() * 3.6), "DAMAGED" if not tank.engine.operational else "OK"]
	ballistic_label.text = "GUN %0.0fmm  |  MV %0.0fm/s  |  PEN @100m %0.0fmm" % [tank.tank_data.cannon_caliber_mm, tank.tank_data.muzzle_velocity_ms, tank.tank_data.penetration_100m_mm]

func _on_destroyed() -> void:
	status_label.text = "VEHICLE DESTROYED"
	reload_label.text = ""
	speed_label.text = ""
	ballistic_label.text = ""

func _on_repair_started(module_name: String, duration: float) -> void:
	last_repair_message = "REPAIRING %s  %.1fs" % [module_name.to_upper(), duration]
	reload_label.text = last_repair_message

func _on_repair_finished(module_name: String) -> void:
	last_repair_message = "%s RESTORED" % module_name.to_upper()
	reload_label.text = last_repair_message
