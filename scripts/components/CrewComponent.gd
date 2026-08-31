class_name CrewComponent
extends Node

signal crew_member_lost(role: String)
signal crew_member_repaired(role: String)

var gunner_alive: bool = true
var driver_alive: bool = true
var commander_alive: bool = true
var loader_alive: bool = true

func _ready() -> void:
    reset_state()

func reset_state() -> void:
    gunner_alive = true
    driver_alive = true
    commander_alive = true
    loader_alive = true

func lose_member(role: String) -> void:
    var key: String = role.to_lower()
    if key == "gunner" and gunner_alive:
        gunner_alive = false
        crew_member_lost.emit("Gunner")
    elif key == "driver" and driver_alive:
        driver_alive = false
        crew_member_lost.emit("Driver")
    elif key == "commander" and commander_alive:
        commander_alive = false
        crew_member_lost.emit("Commander")
    elif key == "loader" and loader_alive:
        loader_alive = false
        crew_member_lost.emit("Loader")

func repair_member(role: String) -> void:
    var key: String = role.to_lower()
    if key == "gunner":
        gunner_alive = true
        crew_member_repaired.emit("Gunner")
    elif key == "driver":
        driver_alive = true
        crew_member_repaired.emit("Driver")
    elif key == "commander":
        commander_alive = true
        crew_member_repaired.emit("Commander")
    elif key == "loader":
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
    if gunner_alive:
        return 1.0
    return 2.0

func can_accelerate() -> bool:
    return driver_alive

func steering_multiplier() -> float:
    if driver_alive:
        return 1.0
    return 0.5

func crew_status() -> Dictionary:
    return {"Gunner": gunner_alive, "Driver": driver_alive, "Commander": commander_alive, "Loader": loader_alive}
