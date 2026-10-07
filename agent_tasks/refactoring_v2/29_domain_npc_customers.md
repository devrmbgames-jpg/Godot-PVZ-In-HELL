# Refactoring v2.29 — vertical domains: NPC и Customers

Status: **PLANNED**

Зависимости: [33_domain_dependency_validation.md](33_domain_dependency_validation.md), NPC/Customer execution refactor завершён в 27.

## Goal

Перенести NPC и Customer ownership из horizontal role roots в vertical domains без изменения runtime behavior.

## Scope

Целевые owners:

```text
content/domains/npc/
content/domains/customers/
```

Перенести Components, Relationships, Systems, Observers, Services, Rules/Solvers, Definitions, Entities, AI/dialogue adapters and scenes/resources. Population/schedule/config belongs npc; no district root. Customer-specific trees/adapters import npc contracts, base npc never customer implementation/classes. Cross-owner Dialogue ctx and panel/resource creation move to global UI/glue; domain conversation begin/end/eligibility remain narrow APIs, no domain→UI import. Update E_DistrictNpc→E_Customer hierarchy/callers where it creates implementation cycle; no forwarding superclass. Reciprocal public leaf data references alone do not require another abstraction.

## Rules

- move ownership, not only files;
- обновить все res:// paths, scene ext_resources, tests и docs;
- не оставлять forwarding wrappers в старых roots;
- truly shared code переносить только в `content/shared/`, с явной причиной;
- UI остаётся Godot glue и не превращается в ECS.

## Acceptance

NPC/Customer gameplay код не разделён между старым horizontal root и новым domain без документированного shared contract.
Domain validator PASS.

## Validation

Parser changed scripts + NPC/Customer regression suites + structure validator.
