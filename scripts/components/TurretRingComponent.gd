class_name TurretRingComponent
extends Node

signal damaged(component: TurretRingComponent)
signal destroyed(component: TurretRingComponent)
signal repaired(component: TurretRingComponent)

@export var max_health: float = 100.0
var health: float = 100.0
var operational: bool = true
var rotation_multiplier: float = 1.0

func _ready() -> void:
    reset_state()

func reset_state() -> void:
    health = max_health
    operational = true
    rotation_multiplier = 1.0

func apply_damage(amount: float, lockout: bool) -> void:
    if not operational:
        return
    var safe_amount: float = maxf(0.0, amount)
    health = maxf(0.0, health - safe_amount)
    if lockout or health <= 0.0:
        operational = false
        rotation_multiplier = 0.0
    else:
        rotation_multiplier = 0.25
    damaged.emit(self)
    if not operational:
        destroyed.emit(self)

func repair_basic() -> void:
    health = maxf(35.0, max_health * 0.4)
    operational = true
    rotation_multiplier = 1.0
    repaired.emit(self)
