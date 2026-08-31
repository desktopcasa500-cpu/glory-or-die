class_name CombatHUD
extends CanvasLayer

var tank: TankBase
var status_label: Label
var reload_label: Label
var speed_label: Label

func _ready() -> void:
	status_label = Label.new()
	status_label.position = Vector2(24.0, 22.0)
	status_label.add_theme_font_size_override("font_size", 18)
	add_child(status_label)
	reload_label = Label.new()
	reload_label.position = Vector2(24.0, 52.0)
	reload_label.add_theme_font_size_override("font_size", 15)
	add_child(reload_label)
	speed_label = Label.new()
	speed_label.position = Vector2(24.0, 78.0)
	speed_label.add_theme_font_size_override("font_size", 15)
	add_child(speed_label)

func bind_tank(target: TankBase) -> void:
	tank = target
	tank.tank_destroyed.connect(_on_destroyed)
	tank.repair_started.connect(_on_repair_started)
	tank.repair_finished.connect(_on_repair_finished)

func _process(_delta: float) -> void:
	if tank == null or not is_instance_valid(tank) or tank.tank_data == null:
		return
	status_label.text = "%s  |  HULL %d%%" % [tank.tank_data.tank_name, roundi(tank.hull_health)]
	reload_label.text = "RELOAD  %.1fs" % tank.reload_remaining if tank.reload_remaining > 0.0 else "READY"
	speed_label.text = "SPEED  %d km/h" % roundi(tank.velocity.length() * 3.6)

func _on_destroyed() -> void:
	status_label.text = "VEHICLE DESTROYED"
	reload_label.text = ""
	speed_label.text = ""

func _on_repair_started(module_name: String, duration: float) -> void:
	reload_label.text = "REPAIRING %s  %.1fs" % [module_name, duration]

func _on_repair_finished(module_name: String) -> void:
	reload_label.text = "%s RESTORED" % module_name
