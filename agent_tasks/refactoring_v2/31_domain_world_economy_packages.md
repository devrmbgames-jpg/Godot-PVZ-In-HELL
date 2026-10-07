# Refactoring v2.31 — vertical domains: world gameplay

Status: **PLANNED**

Зависимости: [30_domain_interaction_combat_motion.md](30_domain_interaction_combat_motion.md), соответствующие execution-refactor задачи завершены в 27.

## Goal

Перенести оставшиеся крупные gameplay owners в vertical domains.

## Scope

Как минимум:

```text
content/domains/packages/
content/domains/commerce/
content/domains/quests/
content/domains/challenges/
content/domains/hazards/
content/domains/time/
content/domains/persistence/
content/domains/inventory/
content/domains/district/
content/domains/needs/
```

Inventory может быть объединён с commerce только если ownership действительно единый; не объединять домены ради уменьшения числа папок.

Baseline разделяет inventory и commerce по state/transaction ownership; Hunger — needs, population — district. Отступление требует concrete inventory evidence и обновления dependency map в этом task, не wholesale redesign roadmap.

## Acceptance

Migration map этих domain закрыт; старые wrappers/aliases удалены; resource paths и save-visible contracts сохранены или мигрированы явно.

## Validation

Профильные tests + save/restore smoke при затрагивании persistence + structure validator.
