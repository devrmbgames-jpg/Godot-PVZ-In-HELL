# R12 — Диалоги, условия и загадка

Status: **DONE**

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
- [x] Implement the existing work checklist in small coherent milestones.
- [x] Review material changes and resolve all recorded R-findings.
- [x] Run final task validation according to the documented GUT/headless budget.
- [x] Record owner gameplay/visual QA.

### Decisions
Do not create a parallel planning document. This file remains the authoritative state/router for the feature; source design docs are references, not task state.

### Current
Completed on 2026-09-29. R12 integrates the installed DialogueManager through a typed project-owned adapter and modal presentation. Direct package-number dialogue, riddle/retry flow, one-shot Satisfaction penalty, voluntary refusal, delayed Complaint creation, false `TAKEN` reaction and Aggressive handoff all reuse existing R11 gameplay authority. Actual dialogue state remains separate from perceived text for future R18 Hunger distortion.

### Validation
- R1 (cyclic `CustomerDialogueService <-> CustomerDialoguePanel` class dependency) = **FIXED** by removing the panel-to-service reference.
- R2 (false `TAKEN` dialogue branch unreachable because R11 transitioned directly to Aggressive) = **FIXED**: R11 remains authority for the `visit.aggressive` decision, while R12 owns the reaction dialogue and invokes the bounded Aggressive receiver after complaint creation.
- Focused R12 GUT + `tests/smoke/customer_dialogue_smoke.tscn` = **PASS** in GitHub Actions on the final R12 code.
- Owner gameplay QA in `main_level` = **PASS** on 2026-09-29.
- An unrelated editor resave removed existing GECS system `group` metadata from `main_level.tscn`; merge resolution intentionally keeps the current `master` scene instead of that accidental diff.

### Owner QA / blockers
Owner confirmed the dialogue flow works in `main_level`. No remaining R12 blocker is recorded.

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
- [x] Добавить типизированный адаптер conditions/actions: фаза, Satisfaction, RequestedPackage, Package actual outcome, Terminal declaration, Complaint/dispute state, Opened/Damaged flags, результаты Challenge и будущий Hunger tier.
- [x] Собрать прямой диалог с номером и загадку с выбором/повтором/альтернативной веткой.
- [x] Действия диалога вызывают существующие gameplay-контракты; поддержать voluntary Customer refusal, delayed Complaint и обнаружение false `TAKEN` с переходом в Aggressive. Challenge/Aggressive подключаются через получателей, а не через циклическую зависимость реализации.
- [x] Разделить действительную реплику/переход и воспринимаемый текст для последующей Hunger distortion.

## Критерии готовности

- Номер доступен через разговор, но поиск коробки остаётся задачей игрока.
- Неверный ответ влияет на Satisfaction и ветку; повтор/закрытие разговора не дублирует выдачу или событие.

## Проверки

GUT: conditions/actions и идемпотентность; integration прямого диалога и загадки; smoke закрытия при уходе/смерти NPC. Общие команды и правила завершения — в [README](README.md).

## Границы

Полная Hunger distortion — 18; не изменять плагин DialogueManager. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
