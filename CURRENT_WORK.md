# Current Work

Next: [R18 Hunger / Perception](agent_tasks/roadmap_18_hunger_and_perception.md).

R14 b1238958 and R15 6247b4cc implement light/arrival-to-departure/debug and camera/LOS gaze rules. R16 floor hazard implementation reviewed; GUT 65/65 PASS (522 assertions), strict physical floor/box/airborne/default customer smoke and NPC/navigation/light/gaze regressions PASS. Main headless shutdown clean except external certificate store. Owner route/timing/rendered readability QA remains.

R16 committed `63b340ec`. R17 implementation reviewed (R1–R6 FIXED), final GUT 104/104 PASS (881 assertions), strict combat and light challenge regression PASS; main headless shutdown clean except certificate store. Separate NPC mechanic supports 3 melee + 3 ranged variants, animation hooks, swept projectiles, future AI kind/index API; Player blade and typed attribution use R04/R08. Owner animation/gameplay/layout QA remains. Next: inspect exact R18 hunger/perception owners and specification. Preserve user config, main scene/schedule resaves, addons/gecs and pre-existing untracked UIDs; stage only task authored hunks. Config limits have not blocked work. Goal remains active.
