# Work Tracker

State: active — cart transport fix, base 9c2a2b5.

- [ ] Separate cart transport: grounded kinematic drive, forward/reverse, explicit E release, collision-safe steps/slopes and driver following; smoke/GUT and local commit.
- [ ] Cargo transport assistance with physical collisions, pickup/lifecycle release; load/turn/ramp regressions, documentation and local commit.

S_Push and puzzle Push stay unchanged. Preserve the user's current cart visual geometry. Existing edits to e_pushable_body.gd, main_level.tscn, Floor_Dirt_static.tscn and dirty addons/gecs are outside the implementation and commits.
