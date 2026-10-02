# Current Work

Active: [R23](agent_tasks/roadmap_23_vertical_slice_validation.md), resumed by owner 2026-10-03 on dev. master is strictly read-only. Use develop workflow; addons/gecs user changes remain untouched.

Windows export infrastructure: 8ebf7c55. QA-01/02 repair batch: 357a49b6 (direct view, seam adhesion with jump preservation, living grab guard, Trader E/F and scale-safe stairs). Focused GUT 23/23, 143 assertions; main/exported 120-frame startup PASS with recorded external certificate-store warning only. Structure/diff PASS; formatter unavailable; bounded review no material findings.

Runnable QA build: .export/LATEST.cmd, versioned Windows directories and isolated QA saves. Build after every completed large task. Generated files/logs stay out of Git.

Player QA migrated to [qa_tasks/README.md](qa_tasks/README.md): nine scenarios, ready vs pending mechanics, 17 source tasks linked. Player results remain pending; full-day/rendered/gamepad/audio acceptance belongs to players.

Shared World/primitive map: [task](agent_tasks/primitive_test_scene_shared_world.md) OWNER_QA. Common game_world, floor 80x64m, ten zones, dedicated save and TEST_LEVEL Windows launcher; GUT 2/2, 224 asserts, both maps navigation rebaked (319/106 polygons). Main authored non-World nodes unchanged. Next: remaining QA-03–QA-13. Enlarged main_level/hidden DebugMarkers are owner-authored; prior navigation/full-day draft evidence is stale. Investigate carried-book handoff/aggression during later integration. Preserve NavigationAgent, simple NPC 3+3 attacks/hooks, arrival-to-physical-departure challenge and material_overlay interactive-only contract.

Low-priority queued: [console commands/help/scrolling](agent_tasks/developer_console_testing.md). R21/R22 owner acceptance and earlier implementation evidence remain in their tasks/history.
