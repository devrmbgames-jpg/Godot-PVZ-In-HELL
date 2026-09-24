# Current Work

- Active: R09 implementation ready; awaiting user runtime/visual acceptance. Keep agent_tasks/roadmap_09_package_hazards.md until accepted.
- Stages committed separately: reusable factory/adapters, user smoke runner, toxic/lifetime/follow, one-shot explosions, final reset/fixture/docs.
- Reuse: C_HazardEmitter + DEF_ToxicArea/DEF_Explosion; direct HazardSpawnRequest also works without an origin. HP remains in O_Damage; physical impulses use Godot. No Package branches in effect processors.
- Lifecycle: request dedup + producer guards, independent/follow-loss policies, stable attribution and source C_NoDamage, finite TTL, pending blast resolution before aging, reset persist flag. Origin colliders excluded from blast LOS.
- Validation: static structure, formatter/lint, PowerShell parser and diff checks PASS; focused static review integrated. Godot/GUT/smoke/physics/visual NOT RUN by user instruction.
- Preserve dirty addons/gecs and existing user R08/Carry changes. No pushes.
- Exact next step: user runs .\utils\run_smoke.ps1 -Name hazards and reports results; address reported failures, then close R09 only after acceptance.
- Canonical details: docs/hazards.md, docs/smoke_runner.md, tests/smoke/hazards_smoke.tscn. WORK.md tracks implementation complete/pending acceptance.
