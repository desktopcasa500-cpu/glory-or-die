class_name EngineComponent
extends Node

signal destroyed(component: EngineComponent)
signal repaired(component: EngineComponent)
signal fire_risk_changed(active: bool)

@export var max_health: float = 100.0
var health: float = 100.0
var operational: bool = true
var fire_risk: bool = false
var fire_tick: float = 0.0

func _ready() -> void:
    reset_state()

func reset_state() -> void:
    health = max_health
    operational = true
    fire_risk = false
    fire_tick = 0.0

func apply_damage(amount: float) -> void:
    if not operational:
        return
    health = maxf(0.0, health - maxf(0.0, amount))
    if health <= 0.0:
        _disable_engine()
    elif health < max_health * 0.35 and not fire_risk:
        fire_risk = true
        fire_tick = 0.0
        fire_risk_changed.emit(true)

func _disable_engine() -> void:
    if not operational:
        return
    operational = false
    fire_risk = true
    fire_tick = 0.0
    fire_risk_changed.emit(true)
    destroyed.emit(self)

func repair_basic() -> void:
    health = maxf(35.0, max_health * 0.40)
    operational = true
    fire_risk = false
    fire_tick = 0.0
    fire_risk_changed.emit(false)
    repaired.emit(self)

func _physics_process(delta: float) -> void:
    if not fire_risk:
        return
    fire_tick += delta
    if fire_tick < 1.5:
        return
    fire_tick = 0.0
    if operational:
        health = maxf(0.0, health - 3.0)
    else:
        health = maxf(0.0, health - 2.0)
    fire_risk_changed.emit(true)
    if health <= 0.0 and operational:
        _disable_engine()
