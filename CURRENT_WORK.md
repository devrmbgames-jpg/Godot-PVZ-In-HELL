# Current Work

- Active: R09.1 generic hazard spawn/factory and package adapter; base e9ecb7f. R04/R08 completion confirmed in task_history.
- User requires reusable component-driven mechanics and a simple smoke runner. All runtime/physics/tests remain user-owned; static checks only.
- Design: independent ToxicArea/Explosion prefabs, immutable definitions, C_HazardEmitter on any Entity, typed deduplicated spawn requests, optional follow policy, propagated source veto. Package is an event adapter only.
- Preserve user R08 balance, split Grab/Carry changes and dirty addons/gecs. No broad refactors.
- Smoke runner complete: utils/run_smoke.ps1 + docs/smoke_runner.md; parser/static review PASS. No smoke executed.
- R09.1 complete: generic factory/prefabs/emitter adapters, source veto, stable IDs, request deduplication. Static structure/formatter/lint/diff checks only; runtime NOT RUN.
- Next: R09.2 independent toxic ticks/lifetime.
