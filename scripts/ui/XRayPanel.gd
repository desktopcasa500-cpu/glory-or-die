class_name XRayPanel
extends Control

signal closed()

var tank: TankBase
var visible_modules: Dictionary = {}

func bind_tank(target: TankBase) -> void:
	tank = target
	tank.module_damaged.connect(_on_module_damaged)
	tank.repair_finished.connect(_on_repair_finished)
	queue_redraw()

func _draw() -> void:
	var panel_rect: Rect2 = Rect2(20.0, 20.0, 360.0, 240.0)
	draw_rect(panel_rect, Color(0.03, 0.04, 0.045, 0.94), true)
	draw_line(Vector2(42.0, 58.0), Vector2(358.0, 58.0), Color(0.42, 0.46, 0.50, 0.8), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(42.0, 48.0), "INTERNAL DAMAGE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.9, 0.9, 0.88))
	var rows: Array[String] = ["ENGINE", "AMMO RACK", "TURRET RING", "GUNNER", "DRIVER"]
	for index: int in rows.size():
		var y: float = 92.0 + float(index) * 28.0
		var name: String = rows[index]
		var damaged: bool = bool(visible_modules.get(name, false))
		var state: String = "DAMAGED" if damaged else "OPERATIONAL"
		draw_string(ThemeDB.fallback_font, Vector2(42.0, y), name, HORIZONTAL_ALIGNMENT_LEFT, 150.0, 14, Color(0.78, 0.8, 0.82))
		draw_string(ThemeDB.fallback_font, Vector2(210.0, y), state, HORIZONTAL_ALIGNMENT_LEFT, 120.0, 14, Color(0.88, 0.62, 0.35) if damaged else Color(0.55, 0.76, 0.58))

func _on_module_damaged(module_name: String, _health: float) -> void:
	visible_modules[module_name.to_upper()] = true
	queue_redraw()

func _on_repair_finished(module_name: String) -> void:
	visible_modules[module_name.to_upper()] = false
	queue_redraw()
