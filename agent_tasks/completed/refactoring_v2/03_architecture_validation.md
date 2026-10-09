# Refactoring v2.03 — architecture validation и service smells

Status: **DONE**

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

## Current — 2026-10-07

Добавлены `utils/validate_architecture.py`, explicit `utils/architecture_baseline.json` и 12 Python regression fixtures. Discovery сканирует project-owned GDScript независимо от horizontal/vertical/custom расположения; tests/addons/generated/ignored directories исключены. Lexical filter убирает comments/strings/triple quotes, сохраняя номера строк; это не полный GDScript parser.

Проверяются static generic steps в services role или Service classes, прямые/Callable.bind generic Service steps из Systems (включая shell callers) и прямой ECS.world.query внутри static step. Baseline keys — rule + owning class + method + target, с occurrence budget, конкретной причиной, owning task и removal gate 26/27; пути используются только в diagnostics. Moves не скрывают debt, дополнительный call превышает budget, stale entries требуют удаления. 34 entries: 19 declarations, 11 System calls, 4 step queries. Presentation.update в legacy services является временным role-placement debt (17), не permanent запретом Presentation. Required integrate_forces Solvers, submit/lookup APIs не запрещаются; engine exceptions не используются для generic ticks.

Статические ограничения остаются review rules: indirect/aliased scheduling, polling semantics, authority, reentrancy, result timing. Baseline не свидетельствует о завершении execution migration: 26 удаляет его, 27 требует strict PASS.

Infrastructure repair: восстановлен отсутствующий `tests/smoke/truck_shift_gate_smoke.gd` с isolated real World/truck/package fixture; проверяет unprepared/loaded/unloaded/returned cargo gate, не создаёт main_level/autosave. Шесть R26 task files получили authoritative Task state block; PLANNED и scope сохранены, R26 gameplay не начат. Scene была не открыта в editor (MCP sessions empty), её reference сохранён и теперь resolves.

## Validation result

- `python -B utils/validate_architecture.py`: PASS, 34 explicit legacy findings.
- `python -B utils/validate_architecture.py --strict`: expected FAIL, все 34 findings и nonempty baseline; required future gate не ослаблен.
- `python -B -m unittest discover -s tests/tools -p test_validate_architecture.py`: PASS, 12 tests, включая new step, deferred/direct forwarding, custom System base, extra occurrence, move, new arbitrary path, stale budget, strict empty gate и allowed patterns.
- `python -B -m unittest discover -s tests/tools -p 'test_validate*.py'`: PASS, 45 tests.
- `python -B utils/validate_project_structure.py`: PASS — все 31 infrastructure diagnostics устранены без ослабления validator.
- `utils/run_smoke.ps1 -Name truck_shift_gate -GodotPath .bin/Godot_v4.7.1-stable_win64_console.exe -Frames 360`: PASS. First fixture run caught same-frame receiving guard; fixture исправлен bounded physics-frame wait.
- Godot 4.7.1 headless project loading parsed and executed restored script without script errors/warnings in passing smoke. Standalone `--check-only --script` не разрешает autoload ECS; это не использовано как proof.
- Headless editor import также завершён без GDScript parse/reload diagnostics; editor shutdown сообщает 6 ObjectDB instances/3 resources in use. Поэтому полный clean editor exit не заявляется. Changed-script parser/runtime proof — passing isolated smoke; системное certificate-store сообщение runner исключает по существующему контракту.
- `python -B utils/validate_refactoring_preflight.py` и `git diff --check`: PASS.

Rendered/subjective QA и broad gameplay suite не запускались; для этого guardrail/infrastructure этапа owner QA не требуется.

## Next

[04_identity_persistence_contract.md](04_identity_persistence_contract.md) — identity/current-format fixture и Phase 1 acceptance.
