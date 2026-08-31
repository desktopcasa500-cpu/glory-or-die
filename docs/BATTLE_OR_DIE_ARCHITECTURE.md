# Battle or Die Architecture

## Runtime graph

`GameState` is the only global match coordinator. It owns the 12 `TankData` resources, selects the player vehicle, spawns player/bot tanks and exposes the projectile-impact signal bus.

`TankBase` is a `CharacterBody3D` composed of Engine, AmmoRack, TurretRing and Crew child components. Components emit typed signals upward; the tank emits status, repair and destruction signals outward.

`Projectile` is an independent `Node3D` ballistic simulation. Each physics frame uses a short ray segment to avoid tunneling without paying the cost of rigid-body projectile simulation. Gravity and aerodynamic drag are integrated at a fixed 120 Hz sub-step while the game physics remains at 60 Hz.

On impact, the projectile computes the angle between the incoming vector and the surface normal. Angles above 70° ricochet. Otherwise it emits `GameState.projectile_impact`; the target tank receives the signal, computes effective armor and, after penetration, propagates a directional internal spall cone into the four internal damage systems.

## Damage chain

`Projectile -> GameState.projectile_impact -> TankBase -> Engine / AmmoRack / TurretRing / Crew signals -> HUD/X-Ray`

No projectile script has to know the implementation of a tank component.

## Repair

Holding `F` selects the first damaged operationally-repairable module. A single `Timer` locks the vehicle in place for the repair interval and then asks the component to restore basic function. A component never reaches into the tank parent to repair itself.

## Performance rules

The Compatibility renderer is used exclusively. The gameplay core uses low-poly procedural meshes, one main directional light with shadows disabled, no per-projectile `RigidBody3D`, no dynamic navmesh, and only a handful of particles during catastrophic destruction.

The projectile uses a 120 Hz internal integration step, but the number of ray tests is bounded by frame delta and the projectile lifetime. This keeps collision deterministic enough for the intended arcade-realistic balance while avoiding hundreds of physics bodies.

## Historical-data policy

The numbers in `GameState.gd` are intentionally distinct, historically scaled reference values intended for a playable simulation. They are not presented as a single archival gunnery standard because wartime ammunition, armor quality, production variant and test methodology changed the real-world values.
