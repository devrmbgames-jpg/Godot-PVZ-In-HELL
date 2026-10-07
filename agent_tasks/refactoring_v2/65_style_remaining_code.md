# Refactoring v2.35 — Code Style: remaining project-owned GDScript

Status: **PLANNED**

Зависимости: 64_style_gameplay_services.md.

## Goal

Закрыть всю project-owned GDScript базу, не оставив второстепенные скрипты вне общего стандарта.

## Scope

Проверить и привести к стилю:
- content/entities/**;
- content/ui/**;
- content/ai/**;
- scripts рядом со сценами/resources;
- utils/**;
- tests/** — с разумным исключением для test readability;
- project tooling вне addons/.

## Constraints

Tests тоже должны быть читаемы, но не превращать компактные table-driven fixtures в церемониальный production-код.
Generated/imported files не форматировать вручную.
Third-party addons/ исключены.

## Acceptance

Full-project style scan не находит project-owned GDScript, не относящийся ни к одной завершённой style task.
Style gate + parser PASS.

## Validation

Full project-owned style check, parser, structure.
