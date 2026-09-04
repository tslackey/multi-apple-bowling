# League Night: Bowling Alley Props

20 stylized props. Flat-shaded, one shared 1024x1024 atlas.
Per-prop triangle counts are in the table below.

## Scale
1 Blender unit = 1 metre. Built to real-world scale.

## Contents
| Prop | Tris | Pivot |
|---|---|---|
| lane_section | 1144 | base_center |
| lane_approach | 660 | base_center |
| lane_bumpers | 1552 | base_center |
| bowling_pin | 560 | base_center |
| pin_formation | 5600 | base_center |
| pinsetter | 2886 | world_origin |
| ball_rack | 4796 | base_center |
| house_balls | 1848 | base_center |
| ball_return | 2060 | base_center |
| score_console | 1368 | base_center |
| monitor_rig | 512 | world_origin |
| lane_bench_row | 1144 | base_center |
| lane_single_seat | 432 | base_center |
| shoe_counter | 820 | base_center |
| cubby_wall | 3344 | base_center |
| shoe_pair | 352 | base_center |
| trophy_case | 3442 | world_origin |
| pennant_board | 440 | world_origin |
| bowl_sign | 924 | world_origin |
| arrow_sign | 396 | world_origin |

## Formats
- `pack.glb`: Godot, Three.js, web (Y-up, metres). Recommended.
- `pack.fbx`: Unity/Unreal. In Unity set "Convert Units" on import. In Unreal,
  **disable Generate Lightmap UVs** (this pack uses a single packed UV channel).


## Texturing
One 1024x1024 gradient-ramp atlas, one opaque material + one emissive material.
If props look untextured, ensure `atlas.png` is in the same folder and the material
samples it as Base Color.

## Licence
Base pack: CC0 1.0 (public domain). Use commercially, no attribution required.
