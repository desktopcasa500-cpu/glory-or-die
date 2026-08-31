class_name AmmoRackComponent
extends Node

signal critical_hit(component: AmmoRackComponent)
signal destroyed(component: AmmoRackComponent)
signal repaired(component: AmmoRackComponent)

@export var max_health: float = 100.0
var health: float = 100.0
var operational: bool = true
var catastrophic_triggered: bool = false

func _ready() -> void:
	health = max_health

func apply_damage(amount: float, critical: bool) -> void:
	if catastrophic_triggered:
		return
	health = maxf(0.0, health - amount)
	if critical or health <= 0.0:
		catastrophic_triggered = true
		operational = false
		critical_hit.emit(self)
		destroyed.emit(self)

func repair_basic() -> void:
	catastrophic_triggered = false
	health = maxf(30.0, max_health * 0.45)
	operational = true
	repaired.emit(self)
