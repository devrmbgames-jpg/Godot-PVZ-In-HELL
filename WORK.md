# Work Tracker

Active: R09, base e9ecb7f.

- [x] R09.1: generic spawn, definitions, independent prefabs, reusable emitter and package adapter.
- [x] User smoke runner: PowerShell script and usage (separate local commit).
- [x] R09.2: bounded independent toxic ticks and generic lifetime/follow.
- [x] R09.3: one-shot radial explosion, explicit LOS and physical impulses.
- [x] R09.4: reset/persistence hooks, presentation, independent fixture, static review and handoff.

User runs ALL Godot/GUT/smoke/physics/visual validation. Static checks only. Local commit after each stage; no pushes. Preserve dirty addons/gecs and user's current R08/Carry work.

Implementation complete; acceptance pending user-run hazards smoke and gameplay checks. Task file remains active; no runtime validation claimed.

## User follow-up

- [x] Fix freed-object availability boundary and explosion origin handoff (static validation only).
- [ ] Separate relationship types into structured content/relationships/ with R_ naming; preserve UIDs/references and user scene edits.
