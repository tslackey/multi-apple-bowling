# Game assets

Vendored CC0 3D models for the bowling prototype. These are **source files**, not yet RealityKit/USDZ.

Keep this folder at the repo root so Xcode does not copy GLB/FBX into the app bundle. Convert to USDZ (via Blender or Reality Converter) before adding models to `Multi Platform Bowling/`.

## Layout

```text
Assets/ThirdParty/
├── LeagueNight/     environment: lanes, pins, pinsetter, props  (GLB + FBX)
└── CC0Tree/         gameplay ball + pin, plus a few env extras  (FBX)
```

| Pack | Role | Formats | License |
| --- | --- | --- | --- |
| [League Night: Bowling Alley Props](https://thesidequestshop.itch.io/league-night-bowling-alley-props) | Lane, approach, gutters/bumpers, pins, pinsetter, ball rack/return, scoring, seating, shoe counter, signs | `pack.glb`, `pack.fbx`, `atlas.png` | CC0 1.0 |
| [CC0Tree](https://github.com/SkywolfGameStudios/CC0Tree) | Lightweight bowling ball + pin; tree and trash-can extras | `.fbx` | CC0 1.0 |

Both packs allow commercial use, modification, and redistribution with **no attribution required**. Source notes and the original license texts live next to the files.

## How we plan to use them

```text
                    BOWLING GAME
                         │
          ┌──────────────┴──────────────┐
          │                             │
      Environment                    Gameplay
          │                             │
    League Night                    RealityKit
          │                             │
    ┌─────┼─────┐                 ┌─────┼─────┐
    │     │     │                 │     │     │
   Lane  Pins  Props             Ball  Pins  Physics
    │           │
    └───────────┘
          │
       CC0Tree
```

Materials (ball color, pin stripes, lane wood, gutters, neon, team colors) can be authored in-engine so we are not locked to the pack palettes.

League Night is real-world scaled (1 unit = 1 metre) and ships GLB, which is the easier import path: **GLB/FBX → Blender → USDZ** for RealityKit on Apple TV and Mac.

## RealityKit import

1. Open `pack.glb` (alley) or the CC0Tree FBX files in Blender.
2. Split the League Night pack into per-prop objects if needed (`lane_section`, `bowling_pin`, `pinsetter`, …).
3. Export USDZ (or USDA + textures) and add those to the Xcode target.
4. Load with `Entity(named:)` / `ModelEntity.load(named:)`.

GLB/FBX will not load directly in RealityKit. Convert with:

```text
make assets
```

That writes `Multi Platform Bowling/Multi Platform Bowling/Resources/LeagueNight.usdz` for the Mac/tvOS host. The CC0Tree ball FBX is still source-only; gameplay uses a RealityKit sphere sized to match (~0.216 m diameter).
