# R14 — Общий lifecycle челленджей и Light On/Off

Status: **OWNER_QA**

## Task state

### Goal
Добавить data-driven Challenge lifecycle и первого опасного клиента со световым условием.

### Constraints / acceptance
- This is a Feature-level tracked task.
- Зависимости: R03, R12, R13
- Reuse existing authoritative contracts from completed dependencies; do not duplicate them.
- The existing `## Работы`, `## Критерии готовности`, `## Проверки`, and `## Границы` sections remain the detailed implementation specification.
- Follow Godot 4.7, GECS ownership, physics authority, and validation rules from `AGENTS.md`.

### Milestones
- [x] Reconfirm dependency completion and current production owners/contracts.
- [x] Implement the existing work checklist in small coherent milestones.
- [x] Independently review material changes and resolve all R-findings.
- [x] Run final task validation according to the documented GUT/headless budget.
- [x] Record remaining owner gameplay/visual QA.

### Decisions
This file remains the authoritative state/router for the feature.
- Player experience: understand the request, leave dialogue with control restored, move to the physical switch and observe the consequence. Pillars: readable danger, physical player agency, shared customer service loop.
- Lifecycle/data are generic C_Challenge + DEF_Challenge. Light On/Off are two DEF_LightChallengeCondition configurations consumed by a separate atomic evaluator; future gaze/hazard producers reuse lifecycle without copying Customer AI.
- Live subject-to-player binding is R_ChallengeActor under relationships/challenges. No Entity reference is stored in persistent visit/challenge data.
- Dialogue arms only after the demand line is acknowledged; context.end activates after modal capture is released. Closing before acknowledgement does not start a hidden timer.
- Default authored window: 20 seconds; results remain visible for 3 seconds. Hypothesis: this comfortably covers the counter-to-switch route; owner playtest must verify timing and prompt comprehension. Success/failure deltas +10/-30 are data-driven.
- Generic runtime publishes typed results; customer consequence receiver adjusts dedicated satisfaction delta exactly once and exposes escalation request for R17. Cleanup handles missing/dead/disabled actors, removed customer and day/phase change.
- No challenge input capture or duplicate AI/movement; player keeps physical control throughout the active challenge. Existing package/refusal/dialogue semantics remain unchanged.
- User-requested visit variant starts at arrival at the counter, remains active while the customer walks away, and resolves at exit before removal. Preparation lasts 10 seconds; a continuous 1-second light violation is latched until departure. These authored timings await owner playtest.
- The third customer uses the arrival/departure variant. On-screen debug UI exposes the task, actual/required light, preparation/countdown/violation timers, customer phase and result.
- Delivery payment waits for any armed/active or unconsumed challenge result; declarations and one-time payment IDs retain their contracts.
- Project-owned DialogueResourceLifecycle breaks pinned DialogueManager runtime per-line resource self references when the panel closes, including late coroutine returns. Addon source remains untouched.

### Current
Implementation, independent review and final checks complete. R1 payment-order defect fixed and re-reviewed without new material findings. Next: commit this milestone and continue R15. User config/editor resaves and addon edits remain outside this change.

### Validation
- GUT challenge + dialogue + customer flow + light circuit: 61/61 PASS, 547 assertions; clean shutdown (r14_final_gut.log).
- Strict challenge_light smoke PASS: actual demand acknowledgement/modal release, physical switch success, timeout/escalation once, arrival/departure lifetime and actual HUD text. Strict customer_flow smoke PASS after allowing outcome consumption before NPC removal.
- Structure validation, diff whitespace check and direct main-scene headless startup/shutdown (120 frames) PASS; only external certificate-store error remains. Formatter unavailable; no visual check claimed.
- Dialogue required headless reimport of its one modified asset. Editor plugin/settings errors are not claimed as validation; runtime checks use the successfully compiled resource.

### Review findings
- R1 — FIXED: delivery could settle before a later challenge failure reduced satisfaction. Settlement now defers until resolution/cancellation and consumption. Regressions cover delivery → TAKEN → failure for timed and departure variants, preserving one payment operation.

### Owner QA / blockers
Ручные проверки и результаты игроков: [сценарий QA](../qa_tasks/environment_and_challenges.md).

Игровая приёмка ожидается; перенос не означает успешного прохождения. Реализация и автоматические доказательства остаются в этой задаче.

---

Зависимости: R03, R12, R13
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 08](../docs/roadmap/08_customer_challenge_framework.md), [ТЗ 13](../docs/roadmap/13_environment_interactables.md), [ТЗ 17](../docs/roadmap/17_vertical_slice_scenario.md).

## Цель

Добавить data-driven Challenge lifecycle и первого опасного клиента со световым условием.

## Начать здесь

- [content/scenes/main_level.gd](../content/scenes/main_level.gd)
- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [x] Реализовать Inactive → Armed → Active → Success/Failure → Cleanup, определения trigger/rules/timeout/consequences.
- [x] Связать конкретный Challenge с Customer и получателями; не дублировать Customer AI в каждом варианте.
- [x] Создать Light On/Off как две конфигурации одной проверки световой группы.
- [x] Запускать после реплики, показывать правило и достаточный countdown; success/fail меняют Satisfaction и отправляют запрос escalation.
- [x] Очистить таймеры/эффекты при завершении, удалении клиента, смерти игрока и смене фазы.

## Критерии готовности

- Клиент даёт ограниченное время физически переключить нужную группу света.
- On и Off используют общий код; результат применяется один раз, cleanup возвращает управление.

## Проверки

GUT: все переходы, timeout, повторный trigger, удаление, сброс дня; сценарии успеха и отказа у выключателя. Общие команды и правила завершения — в [README](README.md).

## Границы

Боевой получатель escalation — 17; пока последствие доступно через Satisfaction и typed event. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
