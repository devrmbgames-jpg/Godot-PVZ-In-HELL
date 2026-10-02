# Current Work

Active: [CharacterBody migration](agent_tasks/player_characterbody_migration.md) implementation complete; Windows main/test export next. Updated owner goal QA-14?QA-20 lives in [R23](agent_tasks/roadmap_23_vertical_slice_validation.md). Work only dev; master read-only; user main/project editor resaves and addon edits preserved.

Native player retains authored head/hand/slot paths through shared E_PhysicalCharacter; archived rigid player is content/entities/characters/archive/rigid_player.tscn, NPCs remain rigid. Small collision-safe steps, Ground support impulse, native/rigid contact damage and queued rebound, crouch/cart/save bindings checked. GUT 46/46,571 assertions; final physics rerun 6/6,33. Independent R2 step assistance FIXED/rereviewed. Structure/diff PASS; formatter SKIP. MCP actual native primitive player + frame-timed input verified; visual/full-day acceptance belongs to owner.

Windows launchers currently .export/LATEST.cmd and .export/TEST_LEVEL.cmd (bd8d333c). Rebuild both at completed large milestones, update pointers only after actual scene/120-frame startup. Then remove completed migration task, retain QA scenarios, continue remaining owner fixes.

Completed history: shared World/test map cc638f5d; stairs/nav UID a2e81594; NPC RVO + both nav cell_size0.25 bd8d333c; completed task cleanup1457721f. Pending player checklists remain qa_tasks; runtime logs/builds are ignored.
