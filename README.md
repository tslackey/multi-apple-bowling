# Multi Platform Bowling

Wii Sports–style bowling for Apple TV and Mac, with an iPhone (and later Apple Watch) as the motion controller. RealityKit renders the alley; Core Motion supplies the swing.

## Assets

CC0 source models live in [`Assets/`](Assets/README.md):

- **League Night** — modular lane, pins, pinsetter, and alley props (`GLB` + `FBX`)
- **CC0Tree** — lightweight bowling ball and pin (`FBX`), plus a few environment extras

Both are public-domain (CC0 1.0). Convert League Night for RealityKit with `make assets`.

## Development

Mac is the everyday host. Apple TV is a separate living-room host — `make run` never launches both.

```text
make help          # list commands
make test          # BowlingGameCore unit tests
make run           # macOS host
make run-ios       # iPhone on the LAN if paired, else Simulator
make run-tvos      # Apple TV on the LAN if paired, else Simulator
make assets        # League Night GLB → USDZ
```
