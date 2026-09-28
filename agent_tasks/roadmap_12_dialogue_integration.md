# R12 — Диалоги, условия и загадка

Status: **IN_PROGRESS**

## Task state

### Goal
Подключить диалоговый слой к gameplay без переноса authority в текст/UI.

### Constraints / acceptance
- This is a Feature-level tracked task.
- Зависимости: R02, R11, R11.1
- Reuse existing authoritative contracts from completed dependencies; do not duplicate them.
- The existing `## Работы`, `## Критерии готовности`, `## Проверки`, and `## Границы` sections remain the detailed implementation specification.
- Follow Godot 4.7, GECS ownership, physics authority, and validation rules from `AGENTS.md`.

### Milestones
- [x] Reconfirm dependency completion and current production owners/contracts.
- [ ] Implement the existing work checklist in small coherent milestones.
- [ ] Independently review material changes and resolve all R-findings.
- [ ] Run final task validation according to the documented GUT/headless budget.
- [ ] Record remaining owner gameplay/visual QA.

### Decisions
Do not create a parallel planning document. This file remains the authoritative state/router for the feature; source design docs are references, not task state.

### Current
Branch `feature/r12-dialogue-integration` started from `master@bd1e5a4d928084aa94b346e05a4ebe888dd5c9d1`. R02/R11 are complete; R11.1 runtime contracts required by R12 are present with M1–M5 implementation complete and owner QA recorded. M1 implements a typed DialogueManager context, project-owned modal presentation, and the direct package-number conversation without changing addon code. Next: riddle branching plus idempotent Satisfaction effects.

### Validation
Static review after M1: R1 (cyclic `CustomerDialogueService <-> CustomerDialoguePanel` class dependency) = **FIXED** by removing the panel-to-service reference. Runtime checks have not yet run.

### Owner QA / blockers
No new blocker is recorded. Any unmet dependency discovered during startup moves the task to `BLOCKED` or `DEFERRED` with the exact dependency named.

---

Зависимости: R02, R11, R11.1
Ветка/base: `feature/r12-dialogue-integration` / `master@bd1e5a4d928084aa94b346e05a4ebe888dd5c9d1`.
Источники: [ТЗ 07](../docs/roadmap/07_customer_flow_and_delivery.md), [ТЗ 08](../docs/roadmap/08_customer_challenge_framework.md), [ТЗ 08.1](../docs/roadmap/08_1_arrangement_extended_interactions.md), [ТЗ 09](../docs/roadmap/09_dialogue_system.md).

## Цель

Подключить диалоговый слой к gameplay без переноса authority в текст/UI.

## Начать здесь

- [project.godot](../project.godot)
- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [x] Оценить уже установленный DialogueManager 4.1.0 через локальный API; использовать его без изменения addons и без второго параллельного движка.
- [ ] Добавить типизированный адаптер conditions/actions: фаза, Satisfaction, RequestedPackage, Package actual outcome, Terminal declaration, Complaint/dispute state, Opened/Damaged flags, результаты Challenge и будущий Hunger tier.
- [ ] Собрать прямой диалог с номером и загадку с выбором/повтором/альтернативной веткой.
- [ ] Действия диалога вызывают существующие gameplay-контракты; поддержать voluntary Customer refusal, delayed Complaint и обнаружение false `TAKEN` с переходом в Aggressive. Challenge/Aggressive подключаются через получателей, а не через циклическую зависимость реализации.
- [ ] Разделить действительную реплику/переход и воспринимаемый текст для последующей Hunger distortion.

## Критерии готовности

- Номер доступен через разговор, но поиск коробки остаётся задачей игрока.
- Неверный ответ влияет на Satisfaction и ветку; повтор/закрытие разговора не дублирует выдачу или событие.

## Проверки

GUT: conditions/actions и идемпотентность; integration прямого диалога и загадки; smoke закрытия при уходе/смерти NPC. Общие команды и правила завершения — в [README](README.md).

## Границы

Полная Hunger distortion — 18; не изменять плагин DialogueManager. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
