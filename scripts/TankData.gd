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

func configure(
	p_name: String,
	p_mass_tons: float,
	p_engine_hp: float,
	p_top_speed_kmh: float,
	p_reverse_speed_kmh: float,
	p_armor_front_mm: float,
	p_armor_side_mm: float,
	p_armor_rear_mm: float
) -> void:
	tank_name = p_name
	mass_tons = p_mass_tons
	engine_hp = p_engine_hp
	top_speed_kmh = p_top_speed_kmh
	reverse_speed_kmh = p_reverse_speed_kmh
	armor_front_mm = p_armor_front_mm
	armor_side_mm = p_armor_side_mm
	armor_rear_mm = p_armor_rear_mm

func duplicate_data() -> TankData:
	var result: TankData = TankData.new()
	result.configure(
		tank_name,
		mass_tons,
		engine_hp,
		top_speed_kmh,
		reverse_speed_kmh,
		armor_front_mm,
		armor_side_mm,
		armor_rear_mm
	)
	return result
