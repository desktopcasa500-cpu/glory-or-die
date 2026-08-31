class_name TurretRingComponent
extends Node

signal damaged(component: TurretRingComponent)
signal repaired(component: TurretRingComponent)

var health: float = 100.0
var operational: bool = true
var rotation_multiplier: float = 1.0

func apply_damage(amount: float, severe: bool = false) -> void:
	if not operational:
		return
	health = maxf(0.0, health - maxf(0.0, amount))
	if severe or health <= 0.0:
		rotation_multiplier = 0.0
		operational = false
	else:
		rotation_multiplier = 0.25
	damaged.emit(self)

func repair_basic() -> void:
	health = 35.0
	operational = true
	rotation_multiplier = 0.25
	repaired.emit(self)
