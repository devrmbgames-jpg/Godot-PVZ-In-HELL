# Current Work

- State: active cart transport fix, base 9c2a2b5; user explicitly requires S_Push unchanged.
- Decision: push_cart.tscn becomes a CharacterBody3D transport; physics-step motion, floor snap/step handling, W/S drive, A/D turn, E release. Separate transport capture and driver-follow hook; cargo assistance is stage 2.
- Preserve user geometry in push_cart.tscn; do not commit pre-existing edits in e_pushable_body.gd, main_level.tscn, Floor_Dirt_static.tscn, addons/gecs or untracked marker_shelves_smoke.gd.uid.
- Validation: none for transport yet; current generic Push regression surface is tests/gut/test_s_grab.gd.
- Next: implement C_CartTransport/E_TransportCart/S_CartTransport and narrow input/action/motion hooks, then transport smoke.
