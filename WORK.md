# Work Tracker

State: R06.1 active; base master @ ff2db865612e43c69742ca61bd91eb980e148342.

## Accepted migration

- Scanner: C_Scanner, C_Interactable, C_Grabbable and scan action -> scanner.tscn.
- Terminal: interactable and terminal action -> terminal.tscn.
- Receiving: C_Receiving -> receiving_zone.tscn.
- DaySession: C_PackageLedger -> authored main-level DaySession.
- DayStation: interactable and phase actions -> station scene; sleep action authored override.
- Package: C_PackageState / C_PackageIntegrity -> package.tscn; only spawn-specific C_Package identity remains runtime (generated/restored ID and supplied definition).
- Ownership: C_HeldBy.slot is authoritative; three validated reverse cache entries. Carry alone affects C_CarryLoad. Allowed hand bitmask replaces fixed item hand.
- Capture: one token registry on actor; Carry, Push and each Terminal acquire/release their own token. Focus priority UI > Push > Carry > hands; authored lowered anchors preserve normal Arm transforms.
- Replacement: validate target, slot, reach, ownership and body before releasing occupant at synchronous command boundary.
- Rotation: Carry RMB, active hand generic rotation via separate R action; tools may disable it. Hand use and Alt throws use one swap mapping.
- Push: separate relation/component/system and body integration; fixed forward/yaw velocities, no reverse traction or transform writes.

## Milestones

- [x] Inspector-first migration; scenes load, day-cycle smoke PASS; formatter/structure and diff check PASS. Receiving smoke reaches eight parcels but initial target ray misses; resolve fixture geometry during regression milestone. Main-scene test hardcodes 15 entities, current scene has 16 (existing Bucket).
- [ ] Three-slot ownership, replacement API and rotation data; targeted grab checks.
- [ ] Shared capture, lowered hands, input resolver/G/swap/Terminal; input regressions.
- [ ] Physical Push and authored cart; physics checks.
- [ ] Full relevant regression, durable docs and task closeout.

Existing dirty addons/gecs is outside task scope. No new GUT suite; extend existing grab tests/smokes.
