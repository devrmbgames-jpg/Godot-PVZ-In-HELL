# Runner — результат проверки отдельно от shutdown-диагностики

Status: **IN_PROGRESS**
Technical: **IN_PROGRESS**
Execution order: **5**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`

## Goal / acceptance

Убрать повторные расследования уже классифицированных shutdown-only сообщений,
не скрывая ошибки исполнения и не меняя игровой код. Сохранить полные raw stdout/stderr,
совместимость существующих вызовов и явный результат каждой реально запущенной проверки.

## Current

Q1 реализован у utils/godot_agent.ps1, validation/review checkpoint готовится.
Новый pure result отделяет FunctionalStatus от DiagnosticStatus/Disposition; raw streams
не переписываются, additive result.json хранит native exit/marker/timeout/log paths.
Legacy CLI/expected-negative contract сохранён; optional TimeoutSeconds=0 сохраняет прежнее ожидание.
Автоматически узнаётся только точный Resource exit summary + native Resource::clear callsite,
exit0 и complete marker. ObjectDB без class proof и неизвестные/смешанные строки — FAIL/UNKNOWN.
Это сознательная строгая граница, а не исследование DEFERRED engine retention.
Q2 измерен: native GUT уже поддерживает проверенную pure пару. Runner batch API: NO_CHANGE;
изоляция World/save/physics fixtures не доказана, отдельные процессы сохраняются.
Публичный контракт: [utils/godot_agent.md](../../utils/godot_agent.md).

## Work packages

| Пакет | Проверяемый результат |
| --- | --- |
| Q1 | Чистая классификация результата, regression fixtures и обратная совместимость CLI/manifest; реальная целевая проверка через Godot. |
| Q2 | Измерить стоимость запусков связанной группы; пакетный режим вводить только при доказанной изоляции/выгоде, иначе сохранить отдельные процессы и записать NO_CHANGE с причиной. |

Q2 — ограниченный эксперимент, не обязательная новая test framework и не повод тормозить backlog.

## Entry points / dependency gates

utils/godot_agent.ps1: Get-GodotDiagnostics и вызывающие его parser/GUT/manifest/exit-code ветки;
существующие тесты/fixtures и validation-workflow/references/memory-lifetime.md.
Ни исправление движка, ни исследование [cold retention](cold_snapshot_resource_retention.md)
не требуются и не разрешаются этой задачей. Игровой код, addon, версия Godot — вне scope.

## Next

Закоммитить Q1/Q2 checkpoint, получить immutable read-only review/triage.
Пока reviewer работает — независимая подготовка актуальной QA-сборки C3/parcel;
после terminal review закрыть эту техническую задачу и перейти к разрешённой H4/следующему task.

## Validation / review

Baseline `03899632574c9f37bd2b0ae1dcd1843eb0491037`: точный разрешённый terminal
Resource diagnostic возвращал1 actionable error → wrapper FAIL при marker/exit0.
Regression сначала FAIL (missing result contract), затем PowerShell fixtures9/9 PASS:
exact known/clean, false callsite, mixed/error/assert, unknown/RID/live Node,
exit/timeout/null exit, missing/incomplete marker, локальный expected-negative и неизменность inputs.
Actual Godot runner ParseFiles1/0 PASS с TimeoutSeconds60, native exit0:
`.artifacts/godot_agent/parsefiles-20261016-160225345.{stdout,stderr}.log` + result.json.
Actual default GUT8/8,54 assertions,stderr0,native exit0 PASS:
`gut-20261016-160236013.{stdout,stderr}.log` + result.json в той же папке.
Q2 raw/measurement: `runner_q2_measurement.json` + `runner_q2_{single_stalking,single_parcel,batch_forward,batch_reverse}.*.log`.
Два отдельных pure suites8/54+11/133:2.238s+2.332s=4.570s; batch19/187:2.419s,
reverse19/187:2.419s, выгода47.1%. Одинаковые индивидуальные test names/counts,
все exit0/stderr0; явные boundary rolls без RNG, мутации Resources только через duplicates.
NO_CHANGE общего batch API: существующий native multi-file путь достаточен для этой пары;
результат не распространяется на ECS/lifecycle/save fixtures.
Structure/diff-check PASS; staged agent gate pending. Review REVIEW_PENDING,repair0/2.

## Owner QA / blockers

Rendered QA не нужна и не разрешена. При отсутствии Godot/PowerShell pure fixture тесты
не заменяют реальный runner check: зафиксировать NOT_RUN и продолжить независимые задачи.
Ремонт runner не является prerequisite для каждой правки: до него разрешена документированная
ручная классификация только по действующей engine policy, без повторных одинаковых запусков.
