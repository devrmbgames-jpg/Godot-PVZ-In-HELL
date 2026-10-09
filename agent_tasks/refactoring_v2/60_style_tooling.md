# Refactoring v2.60 — formatter/linter как единый style gate

Status: **PLANNED**

Зависимости: [49_core_architecture_acceptance.md](49_core_architecture_acceptance.md) PASS.

## Goal

Сделать Code Style воспроизводимым для человека, VSCode, Godot и агента до массовой правки исходников.

## Подготовительная локальная защита (2026-10-09)

До начала Phase 3 добавлен **инкрементальный** formatter/linter для текущих агентских задач:
`utils/check_gdscript_format.py` проверяет только новые строки существующих файлов,
новые файлы целиком, поддерживает `--changed` / `--base` / `--strict`, исключает
только внешний lint `class-name` и самостоятельно проверяет утверждённые GECS-роли.
Отсутствие CLI даёт NOT_RUN/exit 2. `utils/validate_agent_changes.py` и
reviewer требуют архитектурной оценки изменённых сцен/кода. Python unit
fixtures находятся в `tests/tools/test_agent_style_guard.py` и
`test_agent_architecture_guard.py`.

**Статус этой задачи остаётся PLANNED:** основной Phase 3 formatter/linter
по всей project-owned базе, миграции Code Style по доменам и конечная
приёмка ещё не выполнялись. Подготовительный gate не заменяет работы 60–66.

## Work

- привести .editorconfig к утверждённому GDScript style contract;
- hard target длины строки: 100;
- tabs/whitespace/end-of-line правила;
- настроить допустимые project conventions для class_name prefixes/suffixes: C_*, S_*, R_*, O_*, DEF_* и другие согласованные роли;
- не переименовывать архитектурные классы только ради generic naming lint;
- сделать CLI formatter/linter воспроизводимым без зависимости от того, открыл ли человек файл в VSCode;
- текущий utils/check_gdscript_format.py заменить/расширить до style check, который проверяет formatter + lint;
- отсутствие обязательного formatter binary/tooling не должно давать ложный зелёный SKIP;
- VSCode, Godot addon, pre-commit и CLI не должны противоречить друг другу;
- предоставить changed-files mode для обычной работы и full-project mode для финальной приёмки.

## Constraints

Не делать массовый format pass в этой задаче. Сначала стабилизировать toolchain, затем форматировать доменными пачками.

## Acceptance

Один документированный CLI path одинаково ловит line length, formatting и lint violations.
Intentional class-name conventions проходят без локального мусора из warning ignores.
Tooling не форматирует addons/.

## Validation

Запустить style gate на небольшом наборе good/bad fixtures или известных файлов и доказать ожидаемые PASS/FAIL.
