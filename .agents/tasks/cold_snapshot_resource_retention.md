# Cold snapshot — отложенная диагностика завершения процесса

Status: **DEFERRED**
Technical: **DEFERRED**
Execution order: **999**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`
Source: [полное исходное ТЗ и доказательства](references/task-refactor-2026-10-17/cold_snapshot_resource_retention.md.txt).

Эта карточка владеет текущим исполнением. Полный объём требований сохранён в Source;
правила чтения и автономного продолжения — в [README](README.md).


## Goal / acceptance

Сохранить исходное доказательство shutdown-only retention и условие пересмотра:
переход проекта на stable Godot 4.8+ с проверкой относящихся upstream fixes.
Независимое расследование этой категории на Godot 4.7.1 не разрешено.

## Current

KNOWN_ENGINE_LIMITATION / DEFERRED по решению владельца от 2026-10-10.
Baseline и current оба показывали shutdown symptom; это не доказательство новой gameplay-утечки.
BASE_SHA: `857ec02d7703eab840dbf496730be48d29294d99`.
TARGET_SHA: `fc58024f827607286afd1d20d009e3bf22495f64`.
Полные контрольные числа, fixture hashes, повторения и команды сохранены без изменения в Source.

## Work packages

Нет разрешённого активного пакета. Исторические команды — доказательства,
не следующая работа. Никакая другая задача не обязана очищать эту категорию до продолжения.

## Entry points / dependency gates

AGENTS.md known limitation; validation-workflow/references/memory-lifetime.md;
tracked cold_snapshot_retention evidence/fixtures, указанные в Source.
4.7.2 не планируется; автономный upgrade для закрытия задачи запрещён.

## Next

При обходе backlog пропустить. Только после выполнения условия пересмотра сравнить
те же контроль/probe на согласованной новой среде, не выводя runtime leak из shutdown counts.

## Validation / review

Сохранённая историческая evidence не становится новым тестом. Новый запуск NOT_RUN.
Подтверждённые runtime growth, leaked live Nodes, use-after-free/double-free и настоящие
lifecycle дефекты не подпадают под эту отсрочку и исправляются в собственном scope.

## Owner QA / blockers

DEFERRED; не менять typing/WeakRef/free/GECS ради исчезновения предупреждений.
[Задача runner](completed/godot_validation_result_classification.md) классифицирует доказанный
результат проверки отдельно от диагностики, но не исправляет движок и не скрывает raw logs.
