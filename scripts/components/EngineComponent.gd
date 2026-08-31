class_name EngineComponent
extends Node

signal destroyed(component: EngineComponent)
signal repaired(component: EngineComponent)
signal fire_risk_changed(active: bool)

@export var max_health: float = 100.0
var health: float = 100.0
var operational: bool = true
var fire_risk: bool = false

func _ready() -> void:
	health = max_health

func apply_damage(amount: float) -> void:
	if not operational:
		return
	health = maxf(0.0, health - maxf(0.0, amount))
	if health <= 0.0:
		operational = false
		fire_risk = true
		fire_risk_changed.emit(true)
		destroyed.emit(self)

func repair_basic() -> void:
	health = max_health * 0.35
	operational = true
	fire_risk = false
	fire_risk_changed.emit(false)
	repaired.emit(self)
