# Refactoring v2.61 — Code Style: ECS core

Status: **PLANNED**

Зависимости: 60_style_tooling.md.

## Goal

Привести Systems, Observers, Components, Relationships и Definitions к human-first Code Style после завершённой архитектурной миграции.

## Scope

- `content/domains/*/{systems,observers,components,relationships,definitions}/**`;
- соответствующие canonical role folders в `content/shared/`.

Сформировать explicit script manifest для 61–65: каждый project-owned `.gd` имеет один owning style task. Последующие задачи исключают уже принятые файлы. Старые horizontal roots не являются style scope и должны отсутствовать после 32.

## Focus

- narrative code;
- descriptive names;
- concrete typing;
- logical blank-line phases;
- intent comments над сложными physics/ECS/transform blocks;
- public API ## docs;
- meaningful regions;
- guard clauses;
- readable boolean rules;
- <=100 chars через естественное wrapping;
- no cosmetic architecture changes.

Не добавлять комментарии к очевидным строкам и не дробить код на бессмысленные tiny helpers.

## Acceptance

Full style gate PASS для перечисленных каталогов.
Parser PASS.
Behavior diff отсутствует.

## Validation

Formatter/linter full scope + Godot parser для затронутых scripts. Профильные tests только если ручная правка могла изменить semantics.
