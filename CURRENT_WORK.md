# Current Work

Active: [R22.5 Architecture Polish](agent_tasks/roadmap_22_5_gecs_architecture_polish.md), [M4 final audit/validation](agent_tasks/r22_5/m4_final_audit_validation.md).

R17 `4615d3b3`: NPC NavigationAgent combat, simple 3+3 melee/ranged and animation hooks. R18 `86f91acc`: Hunger/perception; R19 `c11dea8b`: owned inventory; R20 `0390f1b7`: physical Trader/orders/refusal quest. Timers/conditions/tasks debug UI and arrival-to-physical-departure challenge remain implemented.

R21 agent implementation complete (OWNER_QA): foundation `baaa8478`, return `daf17670`, final relationship/profile/ID/permanent-effect/hazard/reset hardening `a5e72672`. Review R1–R10 FIXED/rechecked. Final GUT 72/72 (530 assertions), strict night_persistence-20261002-091151100.log PASS: 12 Nights through Morning 13, consumed order never respawns, returned parcel stays gone/penalty preserved, late package/number/condition/ink retained, NEVER completion and real Carry/rotation reset. Main headless 120-frame shutdown has external certificate error only; structure/diff PASS. Owner full-day/rendered/gamepad/layout/balance QA remains in owning tasks.

R22 OWNER_QA: M1 `9d4abdec`, M2 complete: ordinary status/box markings plus typed committed damage feedback and context/scanner prompts. Final GUT 109/109 (548 assertions), no leaks; strict player_feedback-20261002-140308131.log and challenge_gaze-20261002-140626943.log PASS. Main headless shutdown: external certificate error only. Structure/diff PASS; separate review no material findings. Details: R22 task and docs/player_feedback.md. No rendered/audio-readability claim.

R22.5 M1 `a32cea51`, M2 `4a368e94`, M3 DONE. 39 scheduled classes have real work; no static System helper/locator/class-call violations. Highlight cleanup/shared targets and domain receiving lookup hardened; shared crouch HeadRoot classified as gameplay geometry with paths/timing preserved. R1–R3 FIXED; two regressions authored, execution reserved for M4. Next: final remaining System/Observer audit, independent review and bounded GUT/main smoke. Preserve user config, main/schedule resaves, addons/gecs and unrelated UIDs. Limits unchanged; goal active.
