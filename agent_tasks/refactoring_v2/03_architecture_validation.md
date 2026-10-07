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

Scan discovery должен покрывать project-owned GDScript независимо от horizontal/vertical layout. Baseline entries привязаны к символу/owner, а не только старому пути; move не должен скрыть нарушение. Задача 26 обнуляет execution baseline, 27 проверяет результат. Engine-bound solvers — отдельная ограниченная категория, не разрешение generic service tick.

### Existing infrastructure failures to close before runtime migration

Phase 0 запуск `validate_project_structure.py` выявил 31 pre-existing errors: отсутствующий script reference в `tests/smoke/truck_shift_gate_smoke.tscn` и 30 task-state errors в шести top-level `agent_tasks/r26*.md`. Эти файлы не менялись в Phase 0. В этой задаче восстановить корректный static smoke fixture reference и нормализовать task-state metadata с сохранением их scope/status; не ослаблять validator и не начинать R26 gameplay. Gate: полный project structure PASS до завершения Phase 1/начала 10. Это infrastructure repair, не service migration baseline и не бессрочный allowlist.

## Acceptance

- Новый скрытый `SomeService.tick()` не проходит validation незаметно.
- Текущие legacy случаи либо временно перечислены как migration baseline, либо validator умеет сравнивать только новые нарушения.
- После Phase 2 migration baseline должен стать пустым или состоять только из документированных engine-bound исключений.

## Validation

Запустить новую проверку на текущей базе и доказать, что она отличает известные legacy smells от допустимых service/solver patterns. Обновить README с точной командой.
