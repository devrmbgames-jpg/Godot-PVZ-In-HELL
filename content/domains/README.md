# Gameplay domains

Target ownership is `content/domains/<owner>/<canonical role>/`; shared foundations use `content/shared/<role>/`. The approved owners and role vocabulary are enforced by `utils/validate_domain_structure.py`. Empty roles are unnecessary.

| Owner | Responsibility |
| --- | --- |
| `npc` | Population/person records, district calendar/schedules, native actors, sensing, intent, route planning, generic LimboAI capabilities and authored lighting geometry. No separate district owner. |
| `customers` | Visit aggregate/appearance, service/home-delivery role bindings, service queue authoring, customer-specific native trees, dialogue session operations and terminal outcomes. |
| `interaction` | Input/focus, access/action resolution, hands/carry/push/cart/slots, authored doors, circuits/flicker requests and their representation. |
| `combat` | Health/damage/resistance policy, attribution, melee/projectiles, impact capture and combat capabilities. Customer-specific combat adaptation remains customers-owned. |
| `motion` | Common native physical character bodies, locomotion/look/posture/stamina and callback solvers. NPC intent selection/preparation belongs npc. |
| `packages` | Manifest/receiving/truck, parcel recipes/state/history/marks/opening/contents/debris, scanner/terminal operations and bounded loot placement. |
| `hazards` | Hazard recipes, geometry/lifetime/emission/follow/damage application and package-hazard fact consumers. |
| `commerce` | Wallet/economy, purchase/upgrade/trader profile, furniture orders/delivery. |
| `inventory` | Item definitions, live ownership, item effects and drop/transfer transactions. |
| `quests` | Issuer/provider definitions, quest records/bindings, committed outcome consumers and deadlines/rewards. |
| `challenges` | Challenge definitions/session bindings, activation/runtime/resolution and scenario representation. Generic circuit/flicker capability belongs interaction. |
| `needs` | Hunger state/policy, food effects and growth/application. |
| `time` | Day/calendar state and explicit transition commands/facts; scheduled phase commit. |
| `persistence` | Store/schema/codec/preflight, passive snapshot reconstruction, Night prepare/capture/write and restore bindings. |

Global `content/ui/`, `content/scenes/`, `content/materials/` and `content/debug/` retain Godot composition and representation. Context/panel construction is existing global UI responsibility. `GameSessionService` is global SceneTree/slot-handoff composition. Authored `NpcLightZone`, customer `NpcServiceRoutes`, `CircuitLightView` and `PackageMarksView` are domain capabilities/representation, not global panel construction.

## Dependency and access contract

`utils/domain_contracts.json` is the explicit source-owner → target-owner → public symbol/path manifest. Each entry declares read/query/request/subscription (and narrowly scoped restore/configuration) rights and observed public methods. A public declaration or placement in contracts/ never authorizes another owner by itself. `sources` records reviewed provenance, not a second runtime registry. Static checks cannot prove field-write semantics: component/record/relationship ownership and the behavior tests remain required.

- Shared imports no domain or global gameplay implementation. Definitions, immutable identity, bounded diagnostic data/operations and native placement algorithms are shared only with concrete multiple consumers.
- Lower capability data/queries/commands/facts serve NPC/customers; quests/challenges/hazards consume producer-owned outcomes. Native NPC base classes/trees never import Customer behavior/role state or customer queue authoring.
- A lower capability does not call its higher behavioral consumer. Actual file/symbol implementation cycles, including public APIs, fail. Reciprocal coarse domain references to declared leaf data/read/query/facts may pass when implementation is acyclic and field authority is one-way. Do not create forwarding wrappers merely to force a coarse domain DAG.
- Domains import neither Persistence nor global panel/context/composition construction. Persistence consumes declared domain snapshot/recipe contracts. Global composition binds startup, SceneTree handoff, native authored lifecycle and UI opening/closure.
- Read/query permits no foreign mutable-field assignment. Requests enter the owning transaction/handler; committed facts describe visible outcomes. Passive restore is separately constrained to declared SAVE_FIELDS/live links and suspended reactions. Existing capability installers may seed their actor recipes; regular writers remain explicit.
- Asset references form a separate graph. Customer trees compose lower NPC trees; base NPC assets cannot use customer assets to conceal a behavioral cycle. Dynamic loads and closed path-prefix guards require owning review/Content Doctor checks.

## Coherent migration

`utils/domain_migration_map.json` names every current gameplay source, target, owner, role, owning task, original native UID, and retained global file. `utils/validate_domain_migration_map.py` checks coverage, canonical target, single target, UID pairing/integrity, and absence of permanent parallel old/new files. The structure gate includes it in transition mode before any move.

29 closes NPC+Customers, including hierarchy/BT/service role and dialogue routing decomposition before their paths move. 30 closes Interaction/Combat/Motion. 31 closes the remaining concrete owners and global SceneTree composition. 32 closes truly shared foundations, including domain-independent identity/diagnostics. Complete owner scripts/resources, all incoming references, tests/tooling discovery, native save golden/codec scene/definition/type paths and closed path-prefix guards in the same coherent owner commit. Preserve .gd.uid and scene/resource UIDs; .godot is generated. Changed save formats are versioned/rejected; no old-save migration. Raw .tscn changes require the editor to be closed.

`legacy_decomposition` in the access manifest names forbidden existing dependencies and their removal task; it does not grant access. Task 33 enables exact legacy exemptions/enforcement immediately after 28 and before 29. An owner cannot become DONE with its exemption; all exemptions/baseline are empty after 32. No temporary compatibility facade survives closure.

Validation during migration:

```text
python utils/validate_project_structure.py
python utils/validate_domain_structure.py
python utils/validate_domain_migration_map.py
```

After migration, strict domain/dependency gates are mandatory. No new role spelling variants (`camponent`, `component`, `geometry`) or unapproved owner (`district`) are allowed.
