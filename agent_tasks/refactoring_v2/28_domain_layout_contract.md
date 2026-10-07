# Refactoring v2.28 — vertical-domain layout contract

Status: **PLANNED**

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
- manifest records allowed source→target edge and public symbol plus read/query/request/subscription rights. Public declaration alone never authorizes an edge or mutation. Runtime graph acyclic; concrete NPC→Customer reverse import, domain→Persistence and cross-owner Dialogue cycles resolved before moving that owner;
- включить transition-mode domain validator в общий structure validator;
- запретить произвольные role-folder spelling variants;
- определить, что считается truly shared и что обязано иметь domain owner;
- подготовить migration map старых horizontal roots → domains/shared.

Migration map включает `.gd.uid`, scene/resource UIDs, preload/load, ext_resources, tests, tooling, save `scene`/`definition`/record `type` paths и closed path-prefix guards. Update `validate_project_structure.py` для domains/shared до первого move, включая private/public/style scans. Dependency enforcement из 33 включается сразу после 28, до 29–32.

Ownership moves режутся по целому owner: его scripts/resources, all incoming references, test/tooling discovery и current-format save adapters входят в один coherent commit. 29 имеет NPC и Customers slices, 30 — Interaction/Combat/Motion, 31 — отдельные оставшиеся owners. No DONE пока весь заявленный map не закрыт. `.tscn` editing соблюдает opened-scene ownership; Godot MCP операции при открытой сцене, raw edits только при закрытой. Generated `.godot/` не является source migration.

NPC/Customer dependency decomposition is one responsibility slice before their path move: base NPC hierarchy/trees import only lower contracts, Customer-specific subtree belongs to Customers; cross-owner ctx belongs existing global UI/scene glue. Do not scatter base-class edits into later Traits/LOD task. Runtime path validator must not treat comments/string literals as class_name code references; declared dynamic loads remain bounded review/Doctor checks. Asset graph is checked separately from code graph.

## Acceptance

- `python utils/validate_domain_structure.py` PASS;
- typo вроде `camponent/` FAIL с подсказкой `components/`;
- migration map покрывает project-owned gameplay files;
- strict mode пока не обязан проходить.

## Validation

Unit tests validator + project structure validation.
