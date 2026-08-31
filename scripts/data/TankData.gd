class_name TankData
extends Resource

@export var tank_name: String = ""
@export var mass_tons: float = 0.0
@export var engine_hp: float = 0.0
@export var top_speed_kmh: float = 0.0
@export var reverse_speed_kmh: float = 0.0
@export var armor_front_mm: float = 0.0
@export var armor_side_mm: float = 0.0
@export var armor_rear_mm: float = 0.0
@export var cannon_caliber_mm: float = 0.0
@export var reload_time_sec: float = 0.0
@export var muzzle_velocity_ms: float = 0.0
@export var penetration_100m_mm: float = 0.0
@export var turret_traverse_deg_sec: float = 0.0
@export var aim_time_sec: float = 2.0
@export var acceleration_factor: float = 1.0

static func create(data_name: String, mass: float, hp: float, speed: float, reverse: float, front: float, side: float, rear: float, caliber: float, reload: float, velocity: float, penetration: float, traverse: float, aim: float, acceleration: float) -> TankData:
	var data: TankData = TankData.new()
	data.tank_name = data_name
	data.mass_tons = mass
	data.engine_hp = hp
	data.top_speed_kmh = speed
	data.reverse_speed_kmh = reverse
	data.armor_front_mm = front
	data.armor_side_mm = side
	data.armor_rear_mm = rear
	data.cannon_caliber_mm = caliber
	data.reload_time_sec = reload
	data.muzzle_velocity_ms = velocity
	data.penetration_100m_mm = penetration
	data.turret_traverse_deg_sec = traverse
	data.aim_time_sec = aim
	data.acceleration_factor = acceleration
	return data
