# R16 — Клиент с опасным полом

Status: **PLANNED**

## Task state

### Goal
Создать третий отличный от света и взгляда челлендж, решаемый предметами мира.

### Constraints / acceptance
- This is a Feature-level tracked task.
- Зависимости: R09, R14
- Reuse existing authoritative contracts from completed dependencies; do not duplicate them.
- The existing `## Работы`, `## Критерии готовности`, `## Проверки`, and `## Границы` sections remain the detailed implementation specification.
- Follow Godot 4.7, GECS ownership, physics authority, and validation rules from `AGENTS.md`.

### Milestones
- [ ] Reconfirm dependency completion and current production owners/contracts.
- [ ] Implement the existing work checklist in small coherent milestones.
- [ ] Independently review material changes and resolve all R-findings.
- [ ] Run final task validation according to the documented GUT/headless budget.
- [ ] Record remaining owner gameplay/visual QA.

### Decisions
Do not create a parallel planning document. This file remains the authoritative state/router for the feature; source design docs are references, not task state.

### Current
Not started under the lean workflow. Next: verify dependencies in `task_history.md` and current code, then choose the first bounded implementation milestone from the existing work list.

### Validation
Not run for this task under the lean workflow.

### Owner QA / blockers
No new blocker is recorded. Any unmet dependency discovered during startup moves the task to `BLOCKED` or `DEFERRED` with the exact dependency named.

---

Зависимости: R09, R14
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 08](../docs/roadmap/08_customer_challenge_framework.md), [ТЗ 17](../docs/roadmap/17_vertical_slice_scenario.md).

## Цель

Создать третий отличный от света и взгляда челлендж, решаемый предметами мира.

## Начать здесь

- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)
- [content/entities/props/box.tscn](../content/entities/props/box.tscn)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [ ] Подключить опасную поверхность к общему Challenge lifecycle и damage pipeline.
- [ ] Разместить безопасные участки и доступные коробки/мебель, позволяющие физически избегать контакта.
- [ ] Определить trigger, длительность/условие успеха, escalation и cleanup.
- [ ] Отличать реальный контакт с опасным полом от положения над ним на коробке.
- [ ] Добавить отдельный профиль клиента; не заменять механику QTE.

## Критерии готовности

- Игрок может пройти/пережить событие с помощью физических предметов.
- Стоя на безопасной коробке, игрок не получает урон за один лишь overlap проекции; после cleanup опасность исчезает.

## Проверки

GUT: правила/урон/cleanup; physics integration пол → коробка → игрок; ручное прохождение безопасным маршрутом. Общие команды и правила завершения — в [README](README.md).

## Границы

Третий challenge обязателен для общего scope, хотя сокращённый сценарий 17 описывает только свет и взгляд. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
