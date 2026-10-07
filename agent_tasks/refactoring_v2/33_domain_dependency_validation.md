# Refactoring v2.33 — domain dependency validation

Status: **PLANNED**

Зависимости: [32_domain_shared_core.md](32_domain_shared_core.md).

## Goal

Не дать vertical domains снова превратиться в общую связанную массу.

## Work

Добавить статический validator допустимых dependency directions.

Проверять project-owned res:// references/imports по domain ownership. Разрешённые cross-domain зависимости должны проходить через:
- typed commands/events;
- stable public domain contracts;
- content/shared low-level contracts;
- явно документированные integration boundaries.

Не строить полноценный GDScript compiler. Проверять надёжно определяемые path-level violations и поддерживать небольшой explicit dependency map.

## Acceptance

- прямой запрещённый импорт внутреннего файла другого domain даёт FAIL;
- public contract path проходит;
- dependency map документирован;
- validator входит в общую structure validation.

## Validation

Validator fixture tests + strict project structure.
