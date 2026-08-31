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
@export var aim_time_sec: float = 1.6
@export var acceleration_factor: float = 1.0
@export var drivetrain_efficiency: float = 0.82
@export var projectile_mass_kg: float = 8.0
@export var projectile_diameter_m: float = 0.08
@export var projectile_drag_coefficient: float = 0.28
@export var hull_health: float = 100.0
@export var impact_damage_factor: float = 34.0
@export var max_hull_damage: float = 68.0
@export var hull_turn_deg_sec: float = 22.0
@export var bot_fire_range: float = 60.0
@export var bot_fire_alignment: float = 0.12
@export var ammo_cookoff_threshold: float = 72.0
@export var turret_ring_lock_threshold: float = 80.0
@export var crew_knockout_threshold: float = 55.0
@export var description: String = ""

static func build(name_value: String, mass: float, hp: float, speed: float, reverse: float, front: float, side: float, rear: float, caliber: float, reload: float, velocity: float, penetration: float, traverse: float, aim: float, acceleration: float, efficiency: float, projectile_mass: float, projectile_diameter: float, drag: float, turn_rate: float, bot_range: float, hull: float, description_text: String) -> TankData:
    var data: TankData = TankData.new()
    data.tank_name = name_value
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
    data.drivetrain_efficiency = efficiency
    data.projectile_mass_kg = projectile_mass
    data.projectile_diameter_m = projectile_diameter
    data.projectile_drag_coefficient = drag
    data.hull_turn_deg_sec = turn_rate
    data.bot_fire_range = bot_range
    data.hull_health = hull
    data.impact_damage_factor = 34.0
    data.max_hull_damage = 68.0
    data.description = description_text
    return data
