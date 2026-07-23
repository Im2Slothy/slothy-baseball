# Slothy Baseball — Community Edition

A free and open-source, standalone batting-practice resource for FiveM. Slothy
Baseball combines requested AI pitching, mouse-controlled PCI hitting, timing
and contact grading, batted-ball physics, swing statistics, sound effects, and
an optional Ball Cam.

> Current version: `1.0.0`

## Showcase

[![Slothy Baseball Community Edition Showcase](https://img.youtube.com/vi/tftYiPxyjCQ/maxresdefault.jpg)](https://youtu.be/tftYiPxyjCQ)

Click the image above to watch the gameplay showcase.

## Status

This repository contains the free Community Edition: a complete
batter-versus-AI batting-practice MVP, It's proof I could bring an idea to life. It will remain free and open source.

The planned expanded edition will be a separate paid product featuring
player-controlled pitching, multiplayer competition, and deeper baseball
systems. Those paid-edition features are not included in this repository.

## Features

- Standalone resource with no framework or database dependency
- Requested AI pitches with configurable pitch types, speed, break, and accuracy
- Reachable pitches both inside and moderately outside the strike zone
- Mouse-controlled, console-style Plate Coverage Indicator (PCI)
- Timing, PCI placement, contact quality, exit velocity, launch angle, and distance
- Visible bat prop synchronized with the batter's swing
- Local batted-ball flight with a red trajectory trail
- Optional elevated Ball Cam with automatic camera return
- Synthesized contact and miss sounds with no external audio dependency
- Fading strike-zone and PCI presentation during pitches and ball flight
- Grove Street batting-practice location included
- Configurable controls, cameras, locations, physics, pitch mix, UI, and debugging
- Session cleanup for cameras, props, peds, NUI focus, controls, and radar

## Requirements

- A FiveM server
- OneSync is not required for the current local batting-practice mode
- No ESX, QBCore, Qbox, inventory, target, or database dependency

## Installation

1. Place the resource in your server resources directory.
2. Ensure the final folder is named `slothy-baseball`.
3. Add the following line to `server.cfg`:

```cfg
ensure slothy-baseball
```

If cloning directly from GitHub, give the clone the runtime resource name:

```bash
git clone <repository-url> slothy-baseball
```

Downloading GitHub's automatically generated ZIP may add a branch suffix to the
folder. Remove that suffix before starting the resource.

## Default location

The included configuration uses the field near Grove Street:

| Role | Coordinates |
| --- | --- |
| Right-handed batter | `-317.03, -1644.56, 31.85, 195.84` |
| AI pitcher | `-302.15, -1641.31, 31.15, 106.22` |
| Ball Cam | `-320.83, -1653.19, 46.63, 297.44` |

Walk to the batting marker and press `E`, or use `/baseball`.

## Controls

| Input | Action |
| --- | --- |
| `E` | Enter batting practice at the marker |
| `Space` | Request one AI pitch |
| Mouse | Move the PCI |
| Left mouse | Swing |
| `C` | Toggle Ball Cam |
| `Backspace` | Exit batting practice |
| `/baseball` | Toggle batting practice |
| `/baseballdebug` | Toggle the diagnostic overlay |

The strike-zone outline is a visual reference rather than a PCI barrier. Players
can chase reachable pitches beyond all four edges. A taken pitch is identified
only after it crosses the plate.

## Configuration

All gameplay and presentation settings are contained in `config.lua`, including:

- Locations and interaction markers
- Batter, pitcher, batting-camera, and Ball Cam placement
- Pitch selection, speed, movement, and strike probability
- PCI movement, size, sensitivity, and smoothing
- Timing and contact windows
- Hit physics and ball-flight presentation
- Bat model and hand attachment
- Sounds, controls, HUD behavior, and debug output

Set `Config.Debug = false` for a production server.

## Exports

The runtime resource is named `slothy-baseball`:

```lua
exports['slothy-baseball']:StartBattingPractice('grove_street')
exports['slothy-baseball']:StopBattingPractice()

local isBatting = exports['slothy-baseball']:IsBatting()
```

## Client events

The public event namespace is `slothy-baseball`.

### Inputs

```lua
TriggerEvent('slothy-baseball:client:requestPitch')
TriggerEvent('slothy-baseball:client:swingInput')
TriggerEvent('slothy-baseball:client:toggleBallCamera')
```

### Gameplay notifications

```lua
AddEventHandler('slothy-baseball:client:started', function(locationId)
end)

AddEventHandler('slothy-baseball:client:stopped', function(locationId)
end)

AddEventHandler('slothy-baseball:client:pitchThrown', function(pitch)
end)

AddEventHandler('slothy-baseball:client:swing', function(swing)
end)

AddEventHandler('slothy-baseball:client:hitResult', function(result)
end)
```

These are local client events in the current MVP. They are not network events.

## Expanded edition

The separate paid edition is planned to build beyond this Community Edition
with features such as:

- Player-controlled pitching
- Pitcher-versus-batter multiplayer sessions
- Batting rounds, scoring, and persistent statistics
- Additional batting locations and handedness support
- Controller support and customizable PCI presets
- Improved batting stances, swing variations, and impact feedback
- Fielding, team play, and complete games

## License

Slothy Baseball Community Edition is released under the `MIT License`.
Copyright (c) 2026 Im2Slothy. See `LICENSE` for the complete terms.

The MIT License applies only to the code published in this Community Edition
repository. A future paid edition may be distributed separately under different
terms.

## Disclaimer

This project is an independent FiveM resource and is not affiliated with or
endorsed by Major League Baseball, MLB The Show, San Diego Studio, Rockstar
Games, Take-Two Interactive, Cfx.re, or FiveM.
