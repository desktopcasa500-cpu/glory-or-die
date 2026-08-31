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
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)
    top_left = _label(Vector2(24,18),24)
    objective_label = _label(Vector2(24,52),18)
    status_label = _label(Vector2(24,92),20)
    reload_label = _label(Vector2(24,120),16)
    stats_label = _label(Vector2(24,148),15)
    ability_label = _label(Vector2(24,176),15)
    reward_label = _label(Vector2(1010,18),16)
    feed_box = RichTextLabel.new()
    feed_box.position = Vector2(24,530)
    feed_box.size = Vector2(600,155)
    feed_box.bbcode_enabled = true
    feed_box.fit_content = false
    feed_box.add_theme_font_size_override("normal_font_size",14)
    root.add_child(feed_box)
    var cross := Label.new()
    cross.text = "+"
    cross.position = Vector2(638,350)
    cross.add_theme_font_size_override("font_size",28)
    root.add_child(cross)
    var help := _label(Vector2(24,690),13)
    help.text = "WASD DRIVE  •  Q/E TURRET  •  LMB FIRE  •  F REPAIR  •  SPACE ABILITY  •  G GARAGE  •  X X-RAY  •  ESC PAUSE"
    _build_garage()
    _build_xray()
    GameState.wave_started.connect(_on_wave_started)
    GameState.progression_changed.connect(_refresh_meta)
    GameState.match_ended.connect(_on_match_ended)

func _label(pos: Vector2, size: int) -> Label:
    var l := Label.new()
    l.position = pos
    l.add_theme_font_size_override("font_size",size)
    root.add_child(l)
    return l

func bind_tank(target: TankBase) -> void:
    tank = target
    if not is_instance_valid(tank):
        return
    if not tank.tank_destroyed.is_connected(_on_destroyed): tank.tank_destroyed.connect(_on_destroyed)
    if not tank.repair_started.is_connected(_on_repair_started): tank.repair_started.connect(_on_repair_started)
    if not tank.repair_finished.is_connected(_on_repair_finished): tank.repair_finished.connect(_on_repair_finished)
    if not tank.status_changed.is_connected(_on_status_changed): tank.status_changed.connect(_on_status_changed)
    if not tank.combat_event.is_connected(push_feed): tank.combat_event.connect(push_feed)
    _on_status_changed()
    _refresh_meta()

func _process(_delta: float) -> void:
    if not is_instance_valid(tank) or tank.tank_data == null:
        return
    top_left.text = "BATTLE OR DIE   |   %s" % tank.tank_data.tank_name.to_upper()
    objective_label.text = "OPERATION %02d/05   %s" % [GameState.campaign_wave, GameState.objective]
    if tank.reload_remaining > 0.0:
        reload_label.text = "CANNON  RELOADING  %0.1fs" % tank.reload_remaining
    elif tank.aim_remaining > 0.0:
        reload_label.text = "CANNON  AIMING  %0.1fs" % tank.aim_remaining
    else:
        reload_label.text = "CANNON  READY"
    var ability: String = tank.tank_data.ability_name
    var cd: float = tank.ability_cooldown_remaining
    ability_label.text = "ABILITY  %s  [%s]" % [ability.to_upper(), "READY" if cd <= 0.0 else "%0.1fs" % cd]
    stats_label.text = "HULL %d%%   SPEED %d km/h   GUN %dmm   PEN %dmm" % [roundi(tank.hull_health),roundi(tank.velocity.length()*3.6),roundi(tank.tank_data.cannon_caliber_mm),roundi(tank.tank_data.penetration_100m_mm)]
    reward_label.text = "LEVEL %02d   XP %04d   CR %04d   SCORE %06d   KILLS %02d" % [GameState.level,GameState.xp,GameState.credits,GameState.score,GameState.kills]

func _on_status_changed() -> void:
    if is_instance_valid(tank) and tank.tank_data != null:
        status_label.text = "HULL %03d%%   %s   ENGINE %s   TURRET %s" % [roundi(tank.hull_health),tank.last_hit_result,"OK" if tank.engine.operational else "OUT","OK" if tank.turret_ring.operational else "LOCKED"]

func _refresh_meta() -> void:
    if not is_instance_valid(tank):
        return

func _on_wave_started(wave: int, objective: String) -> void:
    push_feed("[WAVE %d] %s" % [wave, objective])

func push_feed(text: String) -> void:
    if not is_instance_valid(feed_box):
        return
    feed_box.append_text(text + "\n")
    var lines := feed_box.get_parsed_text().split("\n")
    if lines.size() > 9:
        feed_box.clear()
        for i in range(maxi(0,lines.size()-9), lines.size()):
            feed_box.append_text(lines[i] + "\n")

func _on_destroyed() -> void:
    status_label.text = "VEHICLE DESTROYED"
    push_feed("YOU ARE DESTROYED — ENTER restarts after the operation ends")

func _on_match_ended(won: bool) -> void:
    var title := "OPERATION COMPLETE" if won else "OPERATION FAILED"
    push_feed(title)
    _show_result(title, won)

func _show_result(title: String, won: bool) -> void:
    if is_instance_valid(pause_panel): pause_panel.queue_free()
    pause_panel = Panel.new()
    pause_panel.position = Vector2(420,205)
    pause_panel.size = Vector2(440,240)
    root.add_child(pause_panel)
    var l := Label.new()
    l.position = Vector2(28,24)
    l.text = title
    l.add_theme_font_size_override("font_size",28)
    pause_panel.add_child(l)
    var d := Label.new()
    d.position = Vector2(28,70)
    d.text = "WAVES  %02d/05\nKILLS  %02d\nSCORE  %06d\nLEVEL  %02d" % [GameState.campaign_wave,GameState.kills,GameState.score,GameState.level]
    d.add_theme_font_size_override("font_size",17)
    pause_panel.add_child(d)
    var b := Button.new()
    b.position = Vector2(28,177)
    b.size = Vector2(180,38)
    b.text = "PLAY AGAIN"
    b.pressed.connect(_restart_campaign)
    pause_panel.add_child(b)

func _restart_campaign() -> void:
    if is_instance_valid(pause_panel):
        pause_panel.queue_free()
        pause_panel = null
    var p := GameState.start_campaign()
    bind_tank(p)

func _build_garage() -> void:
    garage = Panel.new()
    garage.position = Vector2(700,80)
    garage.size = Vector2(545,555)
    garage.visible = false
    root.add_child(garage)
    var title := Label.new()
    title.position = Vector2(20,16)
    title.text = "GARAGE / COMMANDER"
    title.add_theme_font_size_override("font_size",23)
    garage.add_child(title)
    garage_info = Label.new()
    garage_info.position = Vector2(250,58)
    garage_info.size = Vector2(275,455)
    garage_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    garage_info.add_theme_font_size_override("font_size",14)
    garage.add_child(garage_info)
    for i in range(GameState.get_tank_names().size()):
        var b := Button.new()
        b.position = Vector2(18,58 + i*39)
        b.size = Vector2(210,32)
        b.text = GameState.get_tank_names()[i]
        b.pressed.connect(_select_tank.bind(b.text))
        garage.add_child(b)
        tank_buttons.append(b)
    _refresh_garage()

func _refresh_garage() -> void:
    if not is_instance_valid(garage_info): return
    var data := GameState.get_selected_data()
    if data == null: return
    garage_info.text = "%s\n\nROLE  %s\nDOCTRINE  %s\nPASSIVE  %s\nABILITY  %s\n\nARMOR  %d / %d / %d mm\nGUN  %d mm\nPENETRATION  %d mm\nRELOAD  %.1fs\nSPEED  %.0f km/h\n\n%s\n\nMASTERy  %d" % [data.tank_name.to_upper(),data.role,data.doctrine,data.passive_name,data.ability_name,roundi(data.armor_front_mm),roundi(data.armor_side_mm),roundi(data.armor_rear_mm),roundi(data.cannon_caliber_mm),roundi(data.penetration_100m_mm),data.reload_time_sec,data.top_speed_kmh,data.description,int(GameState.mastery.get(data.tank_name,0))]
    for b: Button in tank_buttons:
        b.disabled = not GameState.can_use_tank(b.text)

func _select_tank(name_value: String) -> void:
    if not GameState.can_use_tank(name_value): return
    GameState.set_selected_tank(name_value)
    _refresh_garage()
    var p := GameState.start_campaign()
    bind_tank(p)
    garage.visible = false

func toggle_garage() -> void:
    garage.visible = not garage.visible
    if garage.visible:
        _refresh_garage()
        close_overlays_except(garage)

func _build_xray() -> void:
    xray_panel = XRayPanel.new()
    xray_panel.position = Vector2(20,365)
    xray_panel.size = Vector2(420,300)
    xray_panel.visible = false
    root.add_child(xray_panel)

func toggle_xray() -> void:
    xray_panel.visible = not xray_panel.visible
    if xray_panel.visible:
        xray_panel.bind_tank(tank)

func toggle_pause() -> void:
    get_tree().paused = not get_tree().paused
    if get_tree().paused:
        if not is_instance_valid(pause_panel):
            pause_panel = Panel.new()
            pause_panel.position = Vector2(460,245)
            pause_panel.size = Vector2(360,160)
            root.add_child(pause_panel)
            var t := Label.new(); t.position = Vector2(30,25); t.text = "PAUSED"; t.add_theme_font_size_override("font_size",30); pause_panel.add_child(t)
            var h := Label.new(); h.position = Vector2(30,78); h.text = "ESC to resume"; pause_panel.add_child(h)
    elif is_instance_valid(pause_panel):
        pause_panel.queue_free(); pause_panel = null

func close_overlays() -> void:
    garage.visible = false
    xray_panel.visible = false

func close_overlays_except(keep: Control) -> void:
    if keep != garage: garage.visible = false
    if keep != xray_panel: xray_panel.visible = false
