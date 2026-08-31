# Battle or Die

Godot 4 armored-combat foundation targeting the **Compatibility renderer (OpenGL 3)** and low-end hardware.

## Runtime

- Godot 4.x
- Compatibility renderer
- 60 physics ticks/sec
- Low-poly procedural tank meshes
- Signal-driven damage/event flow
- Ballistic projectile simulation with gravity + aerodynamic drag
- Effective armor calculation and automatic ricochet above 70° from the impact normal
- Internal spall cone affecting Engine, Ammo Rack, Turret Ring and Crew
- Crew casualty penalties, field repair with `F`, and X-ray panel with `X`
- Catastrophic ammo-rack cook-off with turret ejection and lightweight fire/smoke particles

## Controls

`WASD` move / steer · `Q/E` traverse turret · mouse button 1 fire · hold `F` repair · `X` X-ray

## Vehicle catalog

Churchill · Hetzer · IS-2 · KV-1 · Panther · Panzer IV · Pershing · Sherman · StuG III · T-34 · Tiger · Tiger II

The catalog uses distinct historical-scale masses, engine outputs, armor, gun calibers, reloads, muzzle velocities and penetration figures for gameplay. They are simulation-ready reference values rather than archival gunnery tables.

## Structure

```text
scripts/
  GameState.gd              # Autoload / catalog / match lifecycle / damage signal bus
  TankData.gd               # Typed resource schema
  TankBase.gd               # Vehicle simulation, repair, turret and cook-off
  Projectile.gd             # Ballistics / drag / gravity / impact
  components/
    EngineComponent.gd
    AmmoRackComponent.gd
    TurretRingComponent.gd
    CrewComponent.gd
  ui/
    CombatHUD.gd
    XRayPanel.gd
scenes/
  Main.tscn
  TankBase.tscn
  Projectile.tscn
```

## Visual references

Reference concepts were generated with **Higgsfield Soul 2.0** and are documented in `docs/HIGGSFIELD_REFERENCES.md`. They are art-direction references; the runtime remains asset-light and procedural so the gameplay core stays compatible with low-end systems.
