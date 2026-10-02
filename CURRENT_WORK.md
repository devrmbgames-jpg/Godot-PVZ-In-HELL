# Current Work

Active: [R22 HUD / World Feedback](agent_tasks/roadmap_22_hud_and_world_feedback.md).

R17 `4615d3b3`: NPC NavigationAgent combat, simple 3+3 melee/ranged and animation hooks. R18 `86f91acc`: Hunger/perception; R19 `c11dea8b`: owned inventory; R20 `0390f1b7`: physical Trader/orders/refusal quest. Timers/conditions/tasks debug UI and arrival-to-physical-departure challenge remain implemented.

R21 agent implementation complete (OWNER_QA): foundation `baaa8478`, return `daf17670`, final relationship/profile/ID/permanent-effect/hazard/reset hardening `a5e72672`. Review R1–R10 FIXED/rechecked. Final GUT 72/72 (530 assertions), strict night_persistence-20261002-091151100.log PASS: 12 Nights through Morning 13, consumed order never respawns, returned parcel stays gone/penalty preserved, late package/number/condition/ink retained, NEVER completion and real Carry/rotation reset. Main headless 120-frame shutdown has external certificate error only; structure/diff PASS. Owner full-day/rendered/gamepad/layout/balance QA remains in owning tasks.

R22 IN_PROGRESS: ordinary Health/Hunger/Money/debt/penalties HUD and native four-face package tags/condition implemented. Strict player_feedback-20261002-133929439.log PASS with debug disabled; structure/diff PASS. No rendered/audio-readability claim. Next: exact prompt/access/tool/throw/combat audit and distinct typed DamageResult player/package/toxic/explosion feedback; scanner/challenge/Terminal presentation already exists and should be reused. Keep debug timers/conditions/tasks available. R22.5 remains deferred until feature layer stable. Preserve user config, main/schedule resaves, addons/gecs and unrelated UIDs. Limits unchanged; goal active.
