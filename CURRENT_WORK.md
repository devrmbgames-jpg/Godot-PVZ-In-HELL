# Current Work

- Active: R08 / Milestone 5 → 5.1; base ed07f56.
- Contract: one C_Health arithmetic path, generic DamageResult event, domain observers for package and living reactions. Keep physics authority and S_Push unchanged.
- User owns ALL runtime/tests; static checks only. Existing dirty addons/gecs untouched.
- Milestone 1 implemented: C_Health migration, DamageResult.EVENT and separate living/package observers. Static checks before commit; no runtime/tests run.
- Milestone 1.1: optional one-shot depletion spawns, presentation data event, package lifecycle hook and cardboard placeholder. No runtime/tests run.
- Milestone 2: physical contact snapshots, receiver thresholds and impulse/energy-bounded directional damage; capture precedes body assistance. Static checks only.
- Milestone 3: per-World contact episodes rearm only on body_exited; removal/disable prune pair and pending state. Sleeping contacts retain consumed state.
- Milestone 4: optional C_ThrowDamage, explicit arm after throw release, one-hit/timeout/pickup termination and separate request instigator.
- Next: finish source-side `C_NoDamage` veto (M5), then **immediately execute M5.1 Damage/Impact GECS architecture gate before any M6 work**.
- M5.1 contract: remove `S_Damage -> S_Grab`, `S_Impact -> S_Damage/S_Grab`, eliminate `S_Damage.submit()` scan of `ECS.world.systems`, separate physics contact capture from scheduled impact resolution, and give `C_ThrowDamage` lifetime a specific query + `iterate()` path while preserving current impact/dedup/throw semantics.
- Do not broaden M5.1 into Grab/Push/Cart/Input refactors; those remain R22.5 unless a minimal seam is required by Damage/Impact decoupling.
