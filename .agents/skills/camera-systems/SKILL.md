---
name: camera-systems
description: >
  Use for first-person/3D camera look, smoothing, pitch/yaw ownership, recoil,
  shake, FOV, camera jitter, clipping, and camera-related motion sickness issues.
---

# Camera Systems

Separate **gameplay look orientation** from **presentation offsets**.

The camera may display recoil, shake, bob, FOV effects, or smoothing, but presentation effects must not silently become authoritative player aim/motion state.

## First-person look

- Preserve one owner for yaw/pitch intent; do not let head, camera, body, and controller each accumulate their own competing rotation.
- Clamp pitch explicitly.
- Keep ordinary roll at zero unless an intentional effect owns roll.
- Raw mouse delta is not frame-rate integrated; do not multiply it by render-frame `delta`.
- Keep sensitivity configurable instead of burying it in multiple camera scripts.

When diagnosing drift/tilt, inspect where each rotation axis is accumulated and whether a child transform is feeding back into the next frame's look direction.

## Smoothing

For frame-rate-independent exponential smoothing use a factor derived from `delta`, e.g. `1.0 - exp(-rate * delta)`, rather than a fixed per-frame lerp factor.

Do not smooth latency-sensitive aim merely because smoothing looks elegant. Apply smoothing to the visual layer when authoritative look must remain immediate.

Reset smoothing/history intentionally on teleport, respawn, camera reparent, or large discontinuity.

## Presentation effects

Apply these additively after base camera orientation/position:
- recoil kick;
- camera shake;
- head bob;
- temporary FOV kick.

They must decay/return to neutral and must not move the physics body.

For shake:
- use bounded/decaying noise or trauma-like amplitude rather than independent random jumps each frame;
- scale intensity by event importance;
- provide reduced-motion options when effects are strong.

## Third-person / obstruction cases

If a task introduces an orbit/third-person camera:
- separate yaw/pitch pivot from camera distance;
- use SpringArm3D or a focused obstruction query for wall push-in;
- do not let collision correction rewrite the player's authoritative transform.

## Validation

- Use live MCP for exact node hierarchy/transform ownership when useful.
- Parser diagnostics prove code validity, not camera feel.
- Camera jitter, motion sickness, recoil strength, bob, FOV, and visual drift require the smallest relevant manual gameplay check unless the user explicitly asks for runtime visual validation.

Source inspiration: adapted selectively from `camera-systems` and technical portions of `game-feel` in `gamedev-skills/awesome-gamedev-agent-skills` (Apache-2.0); project look/input ownership overrides generic patterns.
