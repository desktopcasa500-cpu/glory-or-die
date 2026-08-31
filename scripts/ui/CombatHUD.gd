class_name CombatHUD
extends CanvasLayer

var tank: TankBase
var status_label: Label
var reload_label: Label
var speed_label: Label
var ballistic_label: Label
var match_label: Label
var hint_label: Label
var xray_panel: XRayPanel
var garage_panel: Panel
var garage_title: Label
var garage_data: Label
var tank_buttons: Array[Button] = []

func _ready() -> void:
    status_label = _make_label(Vector2(24.0, 18.0), 22)
    reload_label = _make_label(Vector2(24.0, 50.0), 16)
    speed_label = _make_label(Vector2(24.0, 76.0), 16)
    ballistic_label = _make_label(Vector2(24.0, 102.0), 14)
    match_label = _make_label(Vector2(930.0, 20.0), 16)
    hint_label = _make_label(Vector2(24.0, 680.0), 14)
    hint_label.text = "WASD DRIVE   Q/E TURRET   LMB FIRE   F REPAIR   X X-RAY   R GARAGE"
    _build_garage()
    GameState.match_started.connect(_on_match_started)
    GameState.match_ended.connect(_on_match_ended)

func _make_label(position_value: Vector2, size_value: int) -> Label:
    var label: Label = Label.new()
    label.position = position_value
    label.add_theme_font_size_override("font_size", size_value)
    add_child(label)
    return label

func bind_tank(target: TankBase) -> void:
    tank = target
    if not tank.tank_destroyed.is_connected(_on_destroyed):
        tank.tank_destroyed.connect(_on_destroyed)
    if not tank.repair_started.is_connected(_on_repair_started):
        tank.repair_started.connect(_on_repair_started)
    if not tank.repair_finished.is_connected(_on_repair_finished):
        tank.repair_finished.connect(_on_repair_finished)
    if not tank.status_changed.is_connected(_on_status_changed):
        tank.status_changed.connect(_on_status_changed)
    _on_status_changed()

func _process(_delta: float) -> void:
    if not is_instance_valid(tank) or tank.tank_data == null:
        return
    if tank.reload_remaining > 0.0:
        reload_label.text = "RELOAD %0.1fs" % tank.reload_remaining
    elif tank.aim_remaining > 0.0:
        reload_label.text = "AIM %0.1fs" % tank.aim_remaining
    else:
        reload_label.text = "READY"
    var engine_text: String = "OK"
    if not tank.engine.operational:
        engine_text = "DISABLED"
    speed_label.text = "SPEED %d km/h   ENGINE %s" % [roundi(tank.velocity.length() * 3.6), engine_text]
    ballistic_label.text = "GUN %0.0fmm   MV %0.0fm/s   PEN %0.0fmm" % [tank.tank_data.cannon_caliber_mm, tank.tank_data.muzzle_velocity_ms, tank.tank_data.penetration_100m_mm]
    match_label.text = "BATTLE %02d:%02d   KILLS %02d   ENEMIES %02d" % [_minutes(), _seconds(), GameState.kills, _enemy_count()]

func _minutes() -> int:
    return int(GameState.match_elapsed / 60.0)

func _seconds() -> int:
    return int(GameState.match_elapsed) % 60

func _enemy_count() -> int:
    var count: int = 0
    for enemy: TankBase in GameState.bot_tanks:
        if is_instance_valid(enemy) and not enemy.destroyed:
            count += 1
    return count

func _on_status_changed() -> void:
    if not is_instance_valid(tank) or tank.tank_data == null:
        return
    status_label.text = "%s   |   HULL %d%%" % [tank.tank_data.tank_name.to_upper(), roundi(tank.hull_health)]

func _on_destroyed() -> void:
    status_label.text = "VEHICLE DESTROYED"
    reload_label.text = ""
    speed_label.text = ""
    ballistic_label.text = ""

func _on_repair_started(module_name: String, duration: float) -> void:
    reload_label.text = "REPAIRING %s  %0.1fs" % [module_name.to_upper(), duration]

func _on_repair_finished(module_name: String) -> void:
    reload_label.text = "%s RESTORED" % module_name.to_upper()

func set_xray_panel(panel: XRayPanel) -> void:
    xray_panel = panel

func toggle_xray() -> void:
    if is_instance_valid(xray_panel):
        xray_panel.visible = not xray_panel.visible

func _build_garage() -> void:
    garage_panel = Panel.new()
    garage_panel.position = Vector2(720.0, 70.0)
    garage_panel.size = Vector2(520.0, 570.0)
    garage_panel.visible = false
    add_child(garage_panel)
    garage_title = Label.new()
    garage_title.position = Vector2(24.0, 18.0)
    garage_title.text = "GARAGE / VEHICLE SELECT"
    garage_title.add_theme_font_size_override("font_size", 22)
    garage_panel.add_child(garage_title)
    garage_data = Label.new()
    garage_data.position = Vector2(250.0, 72.0)
    garage_data.size = Vector2(245.0, 440.0)
    garage_data.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    garage_data.add_theme_font_size_override("font_size", 14)
    garage_panel.add_child(garage_data)
    var names: Array[String] = GameState.get_tank_names()
    for index: int in range(names.size()):
        var button: Button = Button.new()
        button.position = Vector2(20.0, 62.0 + float(index) * 39.0)
        button.size = Vector2(205.0, 32.0)
        button.text = names[index]
        button.pressed.connect(_on_tank_button_pressed.bind(names[index]))
        garage_panel.add_child(button)
        tank_buttons.append(button)
    _refresh_garage()

func _on_tank_button_pressed(tank_name: String) -> void:
    if GameState.match_active:
        GameState.end_match()
    GameState.set_selected_tank(tank_name)
    _refresh_garage()
    GameState.start_match(Vector3.ZERO)
    bind_tank(GameState.player_tank)
    garage_panel.visible = false

func _refresh_garage() -> void:
    var data: TankData = GameState.get_selected_data()
    if data == null:
        garage_data.text = ""
        return
    garage_data.text = "%s\n\nMASS %.1f t\nENGINE %.0f hp\nSPEED %.0f / %.0f km/h\nARMOR %.0f / %.0f / %.0f mm\nGUN %.0f mm\nRELOAD %.1f s\nVELOCITY %.0f m/s\nPENETRATION %.0f mm\n\n%s" % [data.tank_name.to_upper(), data.mass_tons, data.engine_hp, data.top_speed_kmh, data.reverse_speed_kmh, data.armor_front_mm, data.armor_side_mm, data.armor_rear_mm, data.cannon_caliber_mm, data.reload_time_sec, data.muzzle_velocity_ms, data.penetration_100m_mm, data.description]
    for button: Button in tank_buttons:
        button.disabled = false

func toggle_garage() -> void:
    if not is_instance_valid(garage_panel):
        return
    garage_panel.visible = not garage_panel.visible
    if garage_panel.visible:
        _refresh_garage()

func _on_match_started(_player: TankBase, _enemies: Array[TankBase]) -> void:
    _refresh_garage()

func _on_match_ended(player_won: bool) -> void:
    if player_won:
        status_label.text = "BATTLE WON"
    else:
        status_label.text = "BATTLE LOST"
