# Refactoring v2.28 — vertical-domain layout contract

Status: **PLANNED**

Зависимости: архитектурная execution-model приёмка текущих доменов завершена.

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
- включить transition-mode domain validator в общий structure validator;
- запретить произвольные role-folder spelling variants;
- определить, что считается truly shared и что обязано иметь domain owner;
- подготовить migration map старых horizontal roots → domains/shared.

## Acceptance

- `python utils/validate_domain_structure.py` PASS;
- typo вроде `camponent/` FAIL с подсказкой `components/`;
- migration map покрывает project-owned gameplay files;
- strict mode пока не обязан проходить.

## Validation

Unit tests validator + project structure validation.
