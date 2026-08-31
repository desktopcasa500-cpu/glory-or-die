class_name CombatHUD
extends CanvasLayer

var tank: TankBase
var root: Control
var top_left: Label
var objective_label: Label
var reward_label: Label
var status_label: Label
var reload_label: Label
var stats_label: Label
var ability_label: Label
var feed_box: RichTextLabel
var garage: Panel
var garage_info: Label
var xray_panel: XRayPanel
var pause_panel: Panel
var tank_buttons: Array[Button] = []

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    top_left = _label(Vector2(24.0, 18.0), 24)
    objective_label = _label(Vector2(24.0, 52.0), 18)
    status_label = _label(Vector2(24.0, 90.0), 19)
    reload_label = _label(Vector2(24.0, 118.0), 16)
    stats_label = _label(Vector2(24.0, 144.0), 15)
    ability_label = _label(Vector2(24.0, 170.0), 15)
    reward_label = _label(Vector2(875.0, 18.0), 15)
    feed_box = RichTextLabel.new()
    feed_box.position = Vector2(24.0, 520.0)
    feed_box.size = Vector2(660.0, 150.0)
    feed_box.bbcode_enabled = true
    feed_box.fit_content = false
    feed_box.scroll_active = false
    feed_box.add_theme_font_size_override("normal_font_size", 14)
    root.add_child(feed_box)
    var cross: Label = Label.new()
    cross.text = "+"
    cross.position = Vector2(632.0, 338.0)
    cross.add_theme_font_size_override("font_size", 27)
    root.add_child(cross)
    var help: Label = _label(Vector2(24.0, 688.0), 13)
    help.text = "WASD DRIVE  •  Q/E TURRET  •  LMB FIRE  •  F REPAIR  •  SPACE ABILITY  •  G GARAGE  •  X X-RAY  •  ESC PAUSE"
    _build_garage()
    _build_xray()
    GameState.wave_started.connect(_on_wave_started)
    GameState.progression_changed.connect(_on_progression_changed)
    GameState.feed_message.connect(push_feed)
    GameState.match_ended.connect(_on_match_ended)

func _label(pos: Vector2, size: int) -> Label:
    var label: Label = Label.new()
    label.position = pos
    label.add_theme_font_size_override("font_size", size)
    root.add_child(label)
    return label

func bind_tank(target: TankBase) -> void:
    tank = target
    if not is_instance_valid(tank):
        return
    if not tank.tank_destroyed.is_connected(_on_destroyed):
        tank.tank_destroyed.connect(_on_destroyed)
    if not tank.repair_started.is_connected(_on_repair_started):
        tank.repair_started.connect(_on_repair_started)
    if not tank.repair_finished.is_connected(_on_repair_finished):
        tank.repair_finished.connect(_on_repair_finished)
    if not tank.status_changed.is_connected(_on_status_changed):
        tank.status_changed.connect(_on_status_changed)
    if not tank.combat_event.is_connected(push_feed):
        tank.combat_event.connect(push_feed)
    _on_status_changed()
    _on_progression_changed()
    _refresh_garage()

func _process(_delta: float) -> void:
    if not is_instance_valid(tank) or tank.tank_data == null:
        return
    top_left.text = "BATTLE OR DIE   |   %s" % tank.tank_data.tank_name.to_upper()
    objective_label.text = "OPERATION %02d/05   •   %s" % [GameState.campaign_wave, GameState.objective]
    if tank.reload_remaining > 0.0:
        reload_label.text = "CANNON  RELOADING  %0.1fs" % tank.reload_remaining
    elif tank.aim_remaining > 0.0:
        reload_label.text = "CANNON  AIMING  %0.1fs" % tank.aim_remaining
    else:
        reload_label.text = "CANNON  READY"
    var ability_state: String = "READY"
    if tank.ability_cooldown_remaining > 0.0:
        ability_state = "%0.1fs" % tank.ability_cooldown_remaining
    ability_label.text = "ABILITY  %s  [%s]" % [tank.tank_data.ability_name.to_upper(), ability_state]
    stats_label.text = "HULL %03d%%   SPEED %02d km/h   GUN %dmm   PEN %dmm" % [roundi(tank.hull_health), roundi(tank.velocity.length() * 3.6), roundi(tank.tank_data.cannon_caliber_mm), roundi(tank.tank_data.penetration_100m_mm)]
    reward_label.text = "LV %02d   XP %04d   CR %05d   SCORE %06d   KILLS %02d" % [GameState.level, GameState.xp, GameState.credits, GameState.score, GameState.kills]

func _on_status_changed() -> void:
    if not is_instance_valid(tank) or tank.tank_data == null:
        return
    status_label.text = "HULL %03d%%   %s   ENGINE %s   TURRET %s" % [roundi(tank.hull_health), tank.last_hit_result, "OK" if tank.engine.operational else "OUT", "OK" if tank.turret_ring.operational else "LOCKED"]

func _on_progression_changed() -> void:
    reward_label.text = "LV %02d   XP %04d   CR %05d   SCORE %06d   KILLS %02d" % [GameState.level, GameState.xp, GameState.credits, GameState.score, GameState.kills]

func _on_wave_started(wave: int, objective: String) -> void:
    push_feed("[WAVE %d] %s" % [wave, objective])

func push_feed(text: String) -> void:
    if not is_instance_valid(feed_box) or text.is_empty():
        return
    feed_box.append_text(text + "\n")
    var lines: PackedStringArray = feed_box.get_parsed_text().split("\n")
    if lines.size() > 9:
        feed_box.clear()
        var first: int = maxi(0, lines.size() - 9)
        for index: int in range(first, lines.size()):
            if not lines[index].is_empty():
                feed_box.append_text(lines[index] + "\n")

func _on_destroyed() -> void:
    status_label.text = "VEHICLE DESTROYED"
    push_feed("YOU ARE DESTROYED")

func _on_repair_started(module_name: String, duration: float) -> void:
    reload_label.text = "REPAIRING  %s  %0.1fs" % [module_name.to_upper(), duration]

func _on_repair_finished(module_name: String) -> void:
    reload_label.text = "%s RESTORED" % module_name.to_upper()

func _on_match_ended(won: bool) -> void:
    var title: String = "OPERATION COMPLETE" if won else "OPERATION FAILED"
    push_feed(title)
    _show_result(title)

func _show_result(title: String) -> void:
    if is_instance_valid(pause_panel):
        pause_panel.queue_free()
    pause_panel = Panel.new()
    pause_panel.position = Vector2(420.0, 198.0)
    pause_panel.size = Vector2(440.0, 278.0)
    root.add_child(pause_panel)
    var title_label: Label = Label.new()
    title_label.position = Vector2(28.0, 22.0)
    title_label.text = title
    title_label.add_theme_font_size_override("font_size", 28)
    pause_panel.add_child(title_label)
    var details: Label = Label.new()
    details.position = Vector2(28.0, 70.0)
    details.text = "WAVES  %02d/05\nKILLS  %02d\nSCORE  %06d\nLEVEL  %02d\nCREDITS  %05d" % [GameState.campaign_wave, GameState.kills, GameState.score, GameState.level, GameState.credits]
    details.add_theme_font_size_override("font_size", 17)
    pause_panel.add_child(details)
    var button: Button = Button.new()
    button.position = Vector2(28.0, 216.0)
    button.size = Vector2(180.0, 38.0)
    button.text = "PLAY AGAIN"
    button.pressed.connect(_restart_campaign)
    pause_panel.add_child(button)

func _restart_campaign() -> void:
    if is_instance_valid(pause_panel):
        pause_panel.queue_free()
        pause_panel = null
    get_tree().paused = false
    var player: TankBase = GameState.start_campaign()
    bind_tank(player)

func _build_garage() -> void:
    garage = Panel.new()
    garage.position = Vector2(692.0, 70.0)
    garage.size = Vector2(550.0, 570.0)
    garage.visible = false
    garage.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(garage)
    var title: Label = Label.new()
    title.position = Vector2(20.0, 16.0)
    title.text = "GARAGE / COMMANDER"
    title.add_theme_font_size_override("font_size", 23)
    garage.add_child(title)
    garage_info = Label.new()
    garage_info.position = Vector2(250.0, 58.0)
    garage_info.size = Vector2(280.0, 450.0)
    garage_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    garage_info.add_theme_font_size_override("font_size", 14)
    garage.add_child(garage_info)
    var names: Array[String] = GameState.get_tank_names()
    for index: int in range(names.size()):
        var button: Button = Button.new()
        button.position = Vector2(18.0, 58.0 + float(index) * 39.0)
        button.size = Vector2(210.0, 32.0)
        button.text = names[index]
        button.pressed.connect(_select_tank.bind(names[index]))
        garage.add_child(button)
        tank_buttons.append(button)
    _refresh_garage()

func _refresh_garage() -> void:
    if not is_instance_valid(garage_info):
        return
    var data: TankData = GameState.get_selected_data()
    if data == null:
        return
    garage_info.text = "%s\n\nROLE  %s\nDOCTRINE  %s\nPASSIVE  %s\nABILITY  %s\n\nARMOR  %d / %d / %d mm\nGUN  %d mm\nPENETRATION  %d mm\nRELOAD  %.1fs\nSPEED  %.0f km/h\n\n%s\n\nMASTERY  %d" % [data.tank_name.to_upper(), data.role, data.doctrine, data.passive_name, data.ability_name, roundi(data.armor_front_mm), roundi(data.armor_side_mm), roundi(data.armor_rear_mm), roundi(data.cannon_caliber_mm), roundi(data.penetration_100m_mm), data.reload_time_sec, data.top_speed_kmh, data.description, int(GameState.mastery.get(data.tank_name, 0))]
    for button: Button in tank_buttons:
        button.disabled = not GameState.can_use_tank(button.text)

func _select_tank(name_value: String) -> void:
    if not GameState.can_use_tank(name_value):
        return
    GameState.set_selected_tank(name_value)
    _refresh_garage()
    var player: TankBase = GameState.start_campaign()
    bind_tank(player)
    garage.visible = false

func toggle_garage() -> void:
    garage.visible = not garage.visible
    if garage.visible:
        _refresh_garage()
        close_overlays_except(garage)

func _build_xray() -> void:
    xray_panel = XRayPanel.new()
    xray_panel.position = Vector2(20.0, 365.0)
    xray_panel.size = Vector2(420.0, 300.0)
    xray_panel.visible = false
    root.add_child(xray_panel)

func toggle_xray() -> void:
    xray_panel.visible = not xray_panel.visible
    if xray_panel.visible:
        xray_panel.bind_tank(tank)
        close_overlays_except(xray_panel)

func toggle_pause() -> void:
    var paused: bool = not get_tree().paused
    get_tree().paused = paused
    if not paused:
        if is_instance_valid(pause_panel):
            pause_panel.queue_free()
            pause_panel = null
        return
    if is_instance_valid(pause_panel):
        return
    pause_panel = Panel.new()
    pause_panel.position = Vector2(460.0, 245.0)
    pause_panel.size = Vector2(360.0, 160.0)
    root.add_child(pause_panel)
    var title: Label = Label.new()
    title.position = Vector2(30.0, 25.0)
    title.text = "PAUSED"
    title.add_theme_font_size_override("font_size", 30)
    pause_panel.add_child(title)
    var help: Label = Label.new()
    help.position = Vector2(30.0, 78.0)
    help.text = "ESC TO RESUME"
    pause_panel.add_child(help)

func close_overlays() -> void:
    garage.visible = false
    xray_panel.visible = false

func close_overlays_except(keep: Control) -> void:
    if keep != garage:
        garage.visible = false
    if keep != xray_panel:
        xray_panel.visible = false
