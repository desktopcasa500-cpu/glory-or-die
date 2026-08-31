class_name XRayPanel
extends Control

var tank: TankBase

func bind_tank(target: TankBase) -> void:
    tank = target
    if not tank.status_changed.is_connected(_on_status_changed):
        tank.status_changed.connect(_on_status_changed)
    queue_redraw()

func _on_status_changed() -> void:
    queue_redraw()

func _draw() -> void:
    var panel_rect: Rect2 = Rect2(12.0, 12.0, 400.0, 272.0)
    draw_rect(panel_rect, Color(0.025, 0.03, 0.035, 0.96), true)
    draw_rect(panel_rect, Color(0.32, 0.36, 0.39, 0.9), false, 1.0)
    draw_string(ThemeDB.fallback_font, Vector2(30.0, 42.0), "INTERNAL / X-RAY", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.9, 0.92, 0.92))
    if not is_instance_valid(tank):
        return
    var rows: Array[String] = ["ENGINE", "AMMO RACK", "TURRET RING", "GUNNER", "DRIVER", "COMMANDER", "LOADER"]
    for index: int in range(rows.size()):
        var y: float = 72.0 + float(index) * 28.0
        var row_name: String = rows[index]
        var operational: bool = _module_operational(row_name)
        var state: String = "OPERATIONAL"
        if not operational:
            state = "DAMAGED"
        var state_color: Color = Color(0.56, 0.78, 0.62)
        if not operational:
            state_color = Color(0.92, 0.56, 0.36)
        draw_string(ThemeDB.fallback_font, Vector2(30.0, y), row_name, HORIZONTAL_ALIGNMENT_LEFT, 150.0, 14, Color(0.78, 0.8, 0.82))
        draw_string(ThemeDB.fallback_font, Vector2(205.0, y), state, HORIZONTAL_ALIGNMENT_LEFT, 140.0, 14, state_color)

func _module_operational(module_name: String) -> bool:
    if module_name == "ENGINE":
        return tank.engine.operational
    if module_name == "AMMO RACK":
        return tank.ammo_rack.operational and not tank.ammo_rack.catastrophic_triggered
    if module_name == "TURRET RING":
        return tank.turret_ring.operational
    if module_name == "GUNNER":
        return tank.crew.gunner_alive
    if module_name == "DRIVER":
        return tank.crew.driver_alive
    if module_name == "COMMANDER":
        return tank.crew.commander_alive
    if module_name == "LOADER":
        return tank.crew.loader_alive
    return false
