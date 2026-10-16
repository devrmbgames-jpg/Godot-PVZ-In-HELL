# Runner — результат проверки отдельно от shutdown-диагностики

Status: **PLANNED**
Technical: **NOT_STARTED**
Execution order: **5**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`

## Goal / acceptance

Убрать повторные расследования уже классифицированных shutdown-only сообщений,
не скрывая ошибки исполнения и не меняя игровой код. Сохранить полные raw stdout/stderr,
совместимость существующих вызовов и явный результат каждой реально запущенной проверки.

## Current

Задача выделена из рефакторинга ТЗ; код runner здесь НЕ изменён.
Основание: [автовыдача](automatic_parcel_handover_and_wrong_recipient_reactions.md)
и [Жуткий](creepy_npc_unpredictable_stalking.md) сохраняют несколько случаев native exit 0
при wrapper FAIL из-за принятой shutdown-категории. Точное поведение runner подтвердить чтением.

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

Прочитать текущий runner/его потребителей и raw examples; написать детерминированные
fixtures для классификатора, затем выполнить Q1. Если нет безопасного способа доказать
shutdown-фазу, сохранить FAIL/UNKNOWN для такого случая, не вводить широкий ignore stderr.

## Validation / review

Обязательная матрица Q1:
- native success marker + exit 0 + только точная разрешённая terminal shutdown-категория
  → functional PASS, diagnostic KNOWN_ENGINE_LIMITATION/DEFERRED;
- parse/runtime/assert error, ненулевой exit, timeout, неполный suite/нет success marker,
  leaked live Node, неизвестная или смешанная диагностика → FAIL/UNKNOWN, не PASS;
- ошибочный stderr вместе с известным warning не скрывается; слово RID/Resource само по
  себе не allowlist; без доказанной фазы завершения не применять исключение;
- старые callers/manifest и статус отдельных тестов сохранены; expected-negative fixture
  исключается только собственным существующим контрактом, не глобальной фильтрацией;
- raw logs сохранены побайтно; regression сначала воспроизводит misclassification, затем проходит.
Для Q2 сравнить одинаковые fixed tests/seed, cleanup/изоляцию и индивидуальные результаты.
Несовместимые fixtures оставить в отдельных процессах. До выполнения всё NOT_RUN/NOT_MEASURED.

## Owner QA / blockers

Rendered QA не нужна и не разрешена. При отсутствии Godot/PowerShell pure fixture тесты
не заменяют реальный runner check: зафиксировать NOT_RUN и продолжить независимые задачи.
Ремонт runner не является prerequisite для каждой правки: до него разрешена документированная
ручная классификация только по действующей engine policy, без повторных одинаковых запусков.
