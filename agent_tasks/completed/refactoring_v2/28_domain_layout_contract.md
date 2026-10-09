# Refactoring v2.28 — vertical-domain layout contract

Status: **DONE**

Зависимости: [27_architecture_acceptance.md](27_architecture_acceptance.md), [40_typed_commands_events.md](40_typed_commands_events.md), [04_identity_persistence_contract.md](04_identity_persistence_contract.md).

## Goal

Зафиксировать целевой vertical-domain layout и включить структурный guardrail до массового перемещения файлов.

## Target

Gameplay ownership живёт в:

```text
content/domains/<domain>/<role>/
content/shared/<role>/
```

Глобальные Godot glue/composition каталоги могут оставаться отдельно: `content/ui/`, `content/scenes/`, `content/materials/`, `content/debug/`.

Canonical role names задаёт `utils/validate_domain_structure.py`.

## Work

- проверить/утвердить список gameplay domains;
- описать dependency direction между domains;
- manifest records allowed source→target edge and public symbol plus read/query/request/subscription rights. Public declaration alone never authorizes an edge or mutation. Actual file/symbol implementation graph acyclic; reciprocal coarse domain read/data/fact edges may be declared when no implementation cycle/writer conflict exists. Do not create wrappers merely to enforce a coarse DAG. NPC→Customer implementation, domain→Persistence and cross-owner Dialogue cycles resolved before moving that owner;
- включить transition-mode domain validator в общий structure validator;
- запретить произвольные role-folder spelling variants;
- определить, что считается truly shared и что обязано иметь domain owner;
- подготовить migration map старых horizontal roots → domains/shared.

Migration map включает `.gd.uid`, scene/resource UIDs, preload/load, ext_resources, tests, tooling, save `scene`/`definition`/record `type` paths и closed path-prefix guards. Update `validate_project_structure.py` для domains/shared до первого move, включая private/public/style scans. Dependency enforcement из 33 включается сразу после 28, до 29–32.

Ownership moves режутся по целому owner: его scripts/resources, all incoming references, test/tooling discovery и current-format save adapters входят в один coherent commit. 29 имеет NPC и Customers slices, 30 — Interaction/Combat/Motion, 31 — отдельные оставшиеся owners. No DONE пока весь заявленный map не закрыт. `.tscn` editing соблюдает opened-scene ownership; Godot MCP операции при открытой сцене, raw edits только при закрытой. Generated `.godot/` не является source migration.

NPC/Customer dependency decomposition is one responsibility slice before their path move: base NPC hierarchy/trees import lower contracts, Customer subtree belongs Customers; cross-owner ctx/UI opening belongs existing global glue. Domains cannot import global panel/context construction; split existing start responsibility into UI routing and domain begin/end API. Do not defer hierarchy changes to Traits/LOD. Validator distinguishes leaf contract reference from behavioral implementation edge and ignores comments/strings as symbols. Dynamic loads remain review/Doctor checks; asset graph separate.

## Acceptance

- `python utils/validate_domain_structure.py` PASS;
- typo вроде `camponent/` FAIL с подсказкой `components/`;
- migration map покрывает project-owned gameplay files;
- strict mode пока не обязан проходить.

## Validation

Unit tests validator + project structure validation.

## Result

Approved 14 owners and canonical roles are documented in `content/domains/README.md`; concrete shared candidates/boundaries in `content/shared/README.md`. Population remains npc; native intent belongs npc, common bodies/solvers motion; service/home role bindings, delivery scenario, service queue authoring/trees and Customer combat adaptation belong customers. Generic light/flicker capability belongs interaction. Actual domain 3D representation/authoring is distinguished from global Control/context/panel construction. Existing GameSessionService is global SceneTree/slot composition.

Explicit `utils/domain_migration_map.json`: **1540 content entries, 1429 moves, 751 original native UID values**, complete horizontal script/UID/scene/resource/dialogue/geometry coverage and retained globals. It records all 29–32 ownership slices, required hierarchy/BT/dialogue/persistence/shared-identity decompositions, and rewrite surfaces including tests, tooling, native golden save paths, codec type paths, closed guards and documentation. No paths moved yet; no legacy wrapper added.

Explicit `utils/domain_contracts.json`: **719 reviewed source-owner/public-symbol access entries**, with target paths, rights, observed public methods and source provenance. **26 aggregated forbidden legacy dependency entries** have exact sources/owning removal task; they are decomposition requirements, never access grants. Task 33 expands these into exact transition exemptions and enforces actual file/symbol implementation cycles before 29. Shared→domain, domain→Persistence/global UI, NPC→Customer behavior are forbidden. Coarse reciprocal leaf-data/fact edges do not require a blanket DAG or wrappers; actual implementation cycles still fail.

The existing transition domain/private-member integration was verified and extended: approved owner list, strict rejection of remaining geometry/presentation/rules/solvers/authoring roots, target-role prefix validation, full map coverage, duplicate/parallel target rejection and original native UID integrity. Map validation is included in project structure before the first move.

## Validation

Executed 2026-10-08:

- Domain structure/migration-map validator fixtures: **13/13 PASS**, including camponent→components suggestion, unknown district→npc owner, remaining legacy roots, vertical/shared private-member discovery, pending/completed move, missing coverage, parallel/colliding targets and script/resource UID preservation.
- `python utils/validate_domain_structure.py`: PASS transition.
- `python utils/validate_domain_migration_map.py`: PASS full map, zero collisions/unclassified gameplay files.
- `python utils/validate_project_structure.py`: PASS, including map/private/public/resource discovery.
- `python utils/validate_refactoring_preflight.py`: PASS.

No project-owned GDScript or authored scene/resource behavior changed; engine/runtime checks remain the PASS checkpoint from 27. Strict mode is intentionally deferred until owner migration completes. No rendered gameplay/subjective visual QA or old-save migration.

## Current / Next

**DONE — PASS** layout/access contract and transition guardrail. Continue [33 — dependency validation](33_domain_dependency_validation.md) immediately, before 29–32 moves. Do not start Phase 3; final authorized stop remains PASS 49.
