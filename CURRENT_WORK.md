# Current Work

Active: [CharacterBody migration](agent_tasks/player_characterbody_migration.md), updated owner goal 2026-10-03; [R23 owner QA scope](agent_tasks/roadmap_23_vertical_slice_validation/owner_qa.md) now includes QA-14–QA-20. Work only dev; master strictly read-only; addons/gecs changes and editor resaves untouched.

Completed: QA-01/02 repairs (historical rigid player), player QA queue, shared game_world + primitive map (cc638f5d), scale-safe edited stairs/stable nav UID (a2e81594), native NPC RVO bd8d333c. RVO relevant GUT 14/14, 56 assertions: real 2m corridor, stationary Trader, three-customer queue, death/reset policy, old NPC/player regressions. Review R1 reset permanently disabled avoidance FIXED/rereviewed. Both authored maps rebaked cell_size 0.25: main 198, primitive 70 polygons; authored capsule radius retained (Recast rounds clearance upward).

Windows launchers: .export/LATEST.cmd and .export/TEST_LEVEL.cmd (main/test bd8d333c, actual scene + 120-frame startup PASS), separate QA profile and map save slot. Rebuild both after completed large milestones; logs/binaries ignored.

Next: complete body-dependent input/impact/transport/snapshot audit, common typed character API, archive old authored player, native CharacterBody locomotion/camera/slots/Ground RayCast/impact. MCP confirmed editor ready on main_level, game stopped, Godot 4.7.1; owner now grants engine/MCP use. New complaints: refusal only after handoff; Terminal truth only debug; liquids auto-upright; immediate dont-look vignette + wall number; flicker-light event, entrance wait, timeout darkness/aggression; knife stab/hammer overhead animations + hammer weapon. All recorded in owner_qa.md.

Other earlier QA-03–QA-13 and low-priority [console help/scroll](agent_tasks/developer_console_testing.md) remain queued where compatible. Player/manual full-day acceptance in [qa_tasks](qa_tasks/README.md); owner tests the slice while implementation continues.

Completed task cleanup: 27 DONE/OWNER_QA files removed by explicit owner instruction; pending player scenarios remain in qa_tasks. Local links retargeted to history, completed IDs retained for dependency validation; structure/link check PASS.
