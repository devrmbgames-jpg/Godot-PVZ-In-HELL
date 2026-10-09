---
name: first-person-combat
description: Use for first-person weapon targeting, melee/hitscan, combat feel, damage routing and combat feedback.
---

# First-Person Combat

This is a narrow genre/composition skill, not a replacement combat architecture.

Current project combat, health, grab, interaction focus, and damage services remain authoritative.

## Project combat boundary

- `C_Health` is HP authority.
- Damage goes through `DamageRequest` / `DamageRequestService`; weapons/UI/AI do not directly subtract HP.
- Player melee lifecycle is owned by current combat state/service contracts.
- Held weapon ownership follows existing grab/relationship rules.
- Input must respect `InteractionControlFocus`.
- Presentation effects never become the combat hit-authority.

## Targeting

For first-person attacks, distinguish:
- **aim origin/direction**: normally camera/player look intent;
- **visual weapon/muzzle**: presentation;
- **hit geometry**: the authoritative query/cone/projectile.

Do not make the rendered muzzle offset accidentally change what the player can target unless the design explicitly wants physical muzzle obstruction.

For melee:
- windup -> active -> recovery is an explicit timing contract;
- commit a hit at the intended active window;
- keep reach/cone/line-of-sight data-driven;
- avoid multiple damage commits from one swing unless the attack definition explicitly permits it.

For future hitscan/projectiles:
- hitscan uses an immediate physics query and submits a damage request;
- projectiles own their physical flight/collision but still submit damage through the same damage boundary;
- choose query/projectile based on game design, not claims that one API is universally faster/better.

## Feel

Treat combat feedback as presentation layered on confirmed outcomes:
- weapon animation;
- impact audio/VFX;
- small bounded recoil/shake;
- clear hit/kill confirmation when appropriate.

Feedback may be predicted visually, but authoritative outcome should be reconciled with the actual combat result.

Keep recoil learnable/controlled if ranged weapons are added; avoid permanently modifying base camera orientation with recoil offsets.

## Tuning

Tune related values together rather than in isolation:
- damage;
- attack/fire cadence;
- windup/recovery/reload;
- reach/range;
- target HP;
- movement/control lock during attacks.

For player-facing balance decisions also load `.agents/skills/professional-game-design/SKILL.md`.

## Validation

Use deterministic combat/GUT checks for hit eligibility, single-hit commitment, damage routing, cancellation, and focus conflicts. Aim feel, recoil strength, animation timing, and readability still require focused gameplay QA.

Source inspiration: adapted selectively from the `fps-shooter` genre skill in `gamedev-skills/awesome-gamedev-agent-skills` (Apache-2.0); current project combat architecture overrides generic FPS assumptions.
