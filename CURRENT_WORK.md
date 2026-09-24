# Current Work

- Active: R09 implementation ready; awaiting user runtime/visual acceptance. Keep agent_tasks/roadmap_09_package_hazards.md until accepted.
- Stages committed separately: reusable factory/adapters, user smoke runner, toxic/lifetime/follow, one-shot explosions, final reset/fixture/docs.
- Reuse: C_HazardEmitter + DEF_ToxicArea/DEF_Explosion; direct HazardSpawnRequest also works without an origin. HP remains in O_Damage; physical impulses use Godot. No Package branches in effect processors.
- Lifecycle: request dedup + producer guards, independent/follow-loss policies, stable attribution and source C_NoDamage, finite TTL, pending blast resolution before aging, reset persist flag. Origin colliders excluded from blast LOS.
- Validation: static structure, formatter/lint, PowerShell parser and diff checks PASS; focused static review integrated. Godot/GUT/smoke/physics/visual NOT RUN by user instruction.
- Preserve dirty addons/gecs and existing user R08/Carry changes. No pushes.
- Exact next step: user runs .\utils\run_smoke.ps1 -Name hazards and reports results; address reported failures, then close R09 only after acceptance.
- Canonical details: docs/hazards.md, docs/smoke_runner.md, tests/smoke/hazards_smoke.tscn. WORK.md tracks implementation complete/pending acceptance.

## Follow-up

- User reported freed owner argument failure in S_HazardFollow. Fixed EntityAvailability boundary to validate Variant before narrowing to Entity; explosion origin normalized before typed helper. Runtime NOT RUN.
- User changes present: content/scenes/main_level.tscn and addons/gecs; preserve and exclude from commits.
- Relationship migration: R_HeldBy/R_PushedBy under content/relationships/interaction; R_HazardFollow under content/relationships/gameplay. UIDs/storage/behavior retained; references and structural role rule updated.
- Relationship migration audit complete: production callers/observers/tests use R_*; no legacy C_HeldBy/C_PushedBy/C_HazardFollow paths remain; moved .gd.uid values are preserved. project-rules/gecs-v8 skills and structure validator now enforce R_* relationship naming.
- Next: user reruns hazards smoke; runtime validation still user-owned.
