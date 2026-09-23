# Current Work

- State: active cart transport fix; mobility stage complete, cargo next. User explicitly requires S_Push unchanged.
- Implemented: CharacterBody3D cart, floor snap/step handling, W/S drive, A/D turn, E release; independent TRANSPORT capture and bounded rigid-driver following. Reverse reduces driver lag even at obstacles. Preserve cart visual geometry.
- Paths: C_CartTransport/C_CartDriver/E_TransportCart/S_CartTransport, DEF_CartTransportAction, narrow resolver/input/motion hooks; tests/smoke/cart_transport_smoke.tscn. Generic Push test fixture copied from pre-cart-change 9c2a2b5.
- Validation: focused runtime debugging demonstrated ramp ascent/descent, 12cm bump and reversing away from wall; formatter/lint/structure/diff checks before commit. Final GUT/smoke batch pending per updated AGENTS cadence. Initial broad GUT attempt exposed fixture mismatch (corrected statically) and unrelated newly-authored door Jolt warning.
- Concurrent user commits advanced HEAD and updated AGENTS/test cadence; preserve current main_level, e_pushable_body, floor/dependency edits. No rendered validation requested.
- Next: add physical cargo transport assistance and lifecycle/pickup cleanup, then final regression batch.
