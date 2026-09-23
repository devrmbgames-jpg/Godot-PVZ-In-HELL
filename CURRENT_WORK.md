# Current Work

- Active: R08 / Milestone 1 ? Generic Health unification; base ed07f56.
- Contract: one C_Health arithmetic path, generic DamageResult event, domain observers for package and living reactions. Keep physics authority and S_Push unchanged.
- User owns ALL runtime/tests; static checks only. Existing dirty addons/gecs untouched.
- Milestone 1 implemented: C_Health migration, DamageResult.EVENT and separate living/package observers. Static checks before commit; no runtime/tests run.
- Milestone 1.1: optional one-shot depletion spawns, presentation data event, package lifecycle hook and cardboard placeholder. No runtime/tests run.
- Milestone 2: physical contact snapshots, receiver thresholds and impulse/energy-bounded directional damage; capture precedes body assistance. Static checks only.
- Milestone 3: per-World contact episodes rearm only on body_exited; removal/disable prune pair and pending state. Sleeping contacts retain consumed state.
- Milestone 4: optional C_ThrowDamage, explicit arm after throw release, one-hit/timeout/pickup termination and separate request instigator.
- Next: source-side C_NoDamage veto in the common damage pipeline.
