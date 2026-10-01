# Current Work

Active: [R17 Combat / Impact / NPC attacks](agent_tasks/roadmap_17_combat_and_impact_damage.md).

R14 b1238958 and R15 6247b4cc implement light/arrival-to-departure/debug and camera/LOS gaze rules. R16 floor hazard implementation reviewed; GUT 65/65 PASS (522 assertions), strict physical floor/box/airborne/default customer smoke and NPC/navigation/light/gaze regressions PASS. Main headless shutdown clean except external certificate store. Owner route/timing/rendered readability QA remains.

R16 committed `63b340ec`. R17 direct owners inspected; uncommitted Player melee/attribution scaffolding exists. Owner clarification: NPC attacks use a separate simple mechanic, up to 3 melee + 3 ranged variants, per-variant animation hooks and explicit type/index API for future tactical AI. Next: implement NPC execution and projectile, then pursuit/escalation/Player weapon routing. Preserve user config, main scene/schedule resaves, addons/gecs and pre-existing untracked UIDs; stage only task authored hunks. Config limits have not blocked work. Goal remains active.
