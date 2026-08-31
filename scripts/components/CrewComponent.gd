class_name CrewComponent
extends Node

signal crew_member_lost(role: String)
signal crew_member_repaired(role: String)

var gunner_alive: bool = true
var driver_alive: bool = true
var commander_alive: bool = true

func lose_member(role: String) -> void:
	match role.to_lower():
		"gunner": gunner_alive = false
		"driver": driver_alive = false
		"commander": commander_alive = false
		_: return
	crew_member_lost.emit(role)

func repair_member(role: String) -> void:
	match role.to_lower():
		"gunner": gunner_alive = true
		"driver": driver_alive = true
		"commander": commander_alive = true
		_: return
	crew_member_repaired.emit(role)

func reload_multiplier() -> float:
	return 2.0 if not gunner_alive else 1.0

func aim_multiplier() -> float:
	return 2.0 if not gunner_alive else 1.0

func steering_multiplier() -> float:
	return 0.5 if not driver_alive else 1.0

func can_accelerate() -> bool:
	return driver_alive
