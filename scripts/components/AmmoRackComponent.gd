class_name AmmoRackComponent
extends Node

signal critical_hit(component: AmmoRackComponent)
signal repaired(component: AmmoRackComponent)

var operational: bool = true
var health: float = 100.0

func apply_damage(amount: float, critical: bool = false) -> void:
	if not operational:
		return
	health = maxf(0.0, health - maxf(0.0, amount))
	if critical or health <= 0.0:
		operational = false
		critical_hit.emit(self)

func repair_basic() -> void:
	health = 35.0
	operational = true
	repaired.emit(self)
