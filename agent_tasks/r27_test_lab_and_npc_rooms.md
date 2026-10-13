# R27.5 — полный тестовый зал и10 изолированных NPC-комнат

Status: **PLANNED**

Parent: [R27](r27_qa_followup.md).

## Task state

### Goal / acceptance

- Existing primitive_test_level exposes all new R26 items with native physical scenes/capabilities.
- Testing access covers existing gameplay objects/mechanics, including parcel/terminal/truck/trade/day/save.
- Ten isolated authored locations are reachable from the test room and have a return transition.
- Each location contains only one NPC of its specific canonical archetype and receives two parcels/day.
- Explicit owner answer: **reset on every entry**; room does not restore prior progress.
- Native scene change releases old World/systems/roles/UI/signs and initializes the next scene exactly once.
- Repeated entry/return does not leak live Nodes, duplicate entities, stale bindings or inventory/slot references.
- Deterministic headless transitions/day-cycles and catalog/scene checks; Windows test-level export near closure.
- Do not overwrite gameplay saves; use isolated test-room save/session contract.

### Current

Source `d0568a32b4f80ab02a9ab8ab0d84babe341a91be`;
authored `content/scenes/primitive_test_level.tscn` and R26 catalog own the starting surface.
Live MCP editor connected; author scenes/resources through native editor operations.
No dynamic gameplay .gd/.tscn generation. Implementation/testing/review NOT_RUN.

### Validation

NOT_RUN for this milestone; require native scene transitions, reset and daily supply coverage.

### Owner QA / blockers

Owner gameplay/visual acceptance of the expanded lab and all ten rooms remains open.

### Next

Inspect existing test room/session transition and author minimal isolated template/ten typed presets.
