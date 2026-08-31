class_name CrewComponent
extends Node

signal crew_member_lost(role: String)
signal crew_member_repaired(role: String)

var gunner_alive: bool = true
var driver_alive: bool = true
var commander_alive: bool = true
var loader_alive: bool = true

func lose_member(role: String) -> void:
	match role.to_lower():
		"gunner":
			if gunner_alive:
				gunner_alive = false
				crew_member_lost.emit("Gunner")
		"driver":
			if driver_alive:
				driver_alive = false
				crew_member_lost.emit("Driver")
		"commander":
			if commander_alive:
				commander_alive = false
				crew_member_lost.emit("Commander")
		"loader":
			if loader_alive:
				loader_alive = false
				crew_member_lost.emit("Loader")

func repair_member(role: String) -> void:
	match role.to_lower():
		"gunner":
			gunner_alive = true
			crew_member_repaired.emit("Gunner")
		"driver":
			driver_alive = true
			crew_member_repaired.emit("Driver")
		"commander":
			commander_alive = true
			crew_member_repaired.emit("Commander")
		"loader":
			loader_alive = true
			crew_member_repaired.emit("Loader")

func reload_multiplier() -> float:
	var result: float = 1.0
	if not gunner_alive:
		result *= 2.0
	if not loader_alive:
		result *= 1.75
	return result

func aim_multiplier() -> float:
	return 2.0 if not gunner_alive else 1.0

func can_accelerate() -> bool:
	return driver_alive

func steering_multiplier() -> float:
	return 0.5 if not driver_alive else 1.0

func crew_status() -> Dictionary:
	return {
		"Gunner": gunner_alive,
		"Driver": driver_alive,
		"Commander": commander_alive,
		"Loader": loader_alive
	}
