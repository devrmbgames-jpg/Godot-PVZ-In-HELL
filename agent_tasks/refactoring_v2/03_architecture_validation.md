# Refactoring v2.03 — architecture validation и service smells

Status: **PLANNED**

Зависимости: [02_execution_ownership_rules.md](02_execution_ownership_rules.md).

## Goal

Добавить дешёвые guardrails, чтобы после полного рефакторинга проект снова не начал накапливать hidden Systems.

## Work

Расширить существующий structural/static validation либо добавить отдельную узкую проверку, которая для project-owned кода обнаруживает как минимум:

- новые `static func tick/update/process` в `content/services/**`;
- `Service.tick/update/process` из `content/systems/**`;
- очевидный shell pattern вида System → единственный generic service tick;
- при возможности — broad `ECS.world.query` внутри явно per-tick service path.

Проверка не должна давать ложный запрет на:
- `Solver.integrate_forces`;
- explicit command API;
- тесты;
- addons;
- заранее оформленные точечные allowlist исключения с причиной.

## Design constraints

- Не строить хрупкий полноценный GDScript parser на regex.
- Если статически надёжно можно проверить только часть smell — проверять эту часть, остальное оставить review rule.
- Allowlist должен быть малым, явным и объяснённым.
- Validator должен быть быстрым и пригодным для запуска на каждом крупном implementation batch.

## Acceptance

- Новый скрытый `SomeService.tick()` не проходит validation незаметно.
- Текущие legacy случаи либо временно перечислены как migration baseline, либо validator умеет сравнивать только новые нарушения.
- После Phase 2 migration baseline должен стать пустым или состоять только из документированных engine-bound исключений.

## Validation

Запустить новую проверку на текущей базе и доказать, что она отличает известные legacy smells от допустимых service/solver patterns. Обновить README с точной командой.
