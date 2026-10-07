# Refactoring v2.31 — vertical domains: world gameplay

Status: **PLANNED**

Зависимости: [28_domain_layout_contract.md](28_domain_layout_contract.md), соответствующие execution-refactor задачи завершены.

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
```

Inventory может быть объединён с commerce только если ownership действительно единый; не объединять домены ради уменьшения числа папок.

## Acceptance

Migration map этих domain закрыт; старые wrappers/aliases удалены; resource paths и save-visible contracts сохранены или мигрированы явно.

## Validation

Профильные tests + save/restore smoke при затрагивании persistence + structure validator.
