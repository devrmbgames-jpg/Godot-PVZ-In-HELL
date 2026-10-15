# PVZ: параллельный read-only reviewer — пилот

Status: **DONE**

## Task state

### Goal

Проверить скорость и качество Main + Reviewer на 2–3 существенных
checkpoints без вмешательства GitHub CI и без одновременных авторов кода.
Исходная ветка `dev`, SHA `6438b85665eaf55e602319f83830dfc79d44a297`.

### Decisions / acceptance

- [x] Main единственный writer/Review Manager; один child reviewer read-only.
- [x] Review pinned `BASE_SHA..TARGET_SHA`, без живого Godot и worktree writes.
- [x] Принятые P0/P1/P2 блокируют DONE до FIXED; отклонённые/устаревшие findings
  требуют evidence, P3 можно обоснованно отложить.
- [x] Максимум два targeted repair/re-review cycles на checkpoint;
  неуспешная приёмка — BLOCKED с evidence по project workflow.
- [x] Примеры промптов и ссылки опубликованы в `docs/`.
- [x] Native read-only reviewer запущен из Codex; Main продолжил независимую сверку logs/SHA.
- [x] Сравнены три значимых checkpoint с серийным режимом; ограничения измерений записаны ниже.

### Current

Implementation policy применена к task-41 и последующим районным checkpoints.
Source review/triage также записаны в [обратном грузе](district_truck_returns_resale.md),
[snapshot](district_save_schema_3.md) и [итоговой интеграции](district_release_validation.md).
Это примеры применения workflow, не измерение сравнительной эффективности.
2026-10-13 тот же освободившийся reviewer последовательно проверил три immutable пары
ниже. Main ожидал результат, без параллельной реализации/тестов. Второй reviewer не запускался.
Никаких дополнительных очередей / Manager Agent / GitHub workflows.

Первый checkpoint, 2026-10-09: Main запустил один native read-only reviewer для task 41 на полном
`857ec02d7703eab840dbf496730be48d29294d99..da636b0c5c46cd82260e58db1a508ca00f531fb8`.
Результат собран и triaged в [owning task 41](refactoring_v2/41_entity_templates_traits.md).
Статусы ошибок и исправления принадлежат task 41, отдельная очередь не создаётся.

### Сравнение трёх checkpoint

Полные immutable пары, все BASE/TARGET — предки текущего code checkpoint
`4c60e3dc784352c2fb95ca617cebbafa9a834366`:

- A, retirement старого map feedback: BASE `32ddcee3f696eb9d48e320091e9b8ed6f0c414ea`
  → TARGET `c02213ef77d055b725cb221adf0b7cf48e89b77a`.
- B, сохранение успешной безопасной retry goal: BASE `526780a07441cb30b2812d9bfe209583096744cc`
  → TARGET `a030253a2ffcb7bf2cc4b4e758629c6dc45225e3`.
- C, retirement endpoint при движущейся опасности: BASE `2da4a456d66a137e5316af2ba87355fa2cc94a08`
  → TARGET `78e9b826470dce320bf9999f495ed0c05ab8c8f5`.

Reviewer измерил реальные UTC timestamps 2026-10-13; секундная точность:

| Пара | Start UTC | End UTC | Serial review | Прежний review | Качество |
| --- | --- | --- | --- | --- | --- |
| A | 01:40:20 | 01:40:46 | 26 s | ≈11 s | новых findings нет; прежний RV-002 resolved |
| B | 01:40:46 | 01:41:13 | 27 s | ≈35 s | новых findings нет; прежний RV-004 resolved |
| C | 01:41:13 | 01:41:38 | 25 s | ≈25 s | новых findings нет; прежний RV-002 resolved |

Общее serial review время 78 s; сумма прежних приблизительных review durations ≈71 s.
Это повторная проверка с уже известным контекстом без контролируемых условий.
Elapsed review не равен общему времени Main+Reviewer. Ускорение или ухудшение эффективности
не установлено; overlap, token usage и сравнение end-to-end производительности **NOT_MEASURED**.
В трёх парах finding parity совпала; architecture/style **PASS**, reviewer validation **NOT_RUN**.
Канонические принятые ошибки остаются FIXED в [connected candidates](npc_hazard_escape_connected_candidates.md)
и [route convergence](npc_route_goal_convergence.md); дубликаты/новая очередь не созданы.

### Validation

- Static inspection: instructions/role contract and frontmatter.
- Native Codex reviewer для task 41 выполнен; точные findings/validation — в owning task.
- PASS: три sequential immutable reviews и сопоставление результатов/elapsed с прежними review.
- NOT_MEASURED: review overlap, token usage и общий выигрыш производительности.
- NOT_RUN: Godot/GUT для policy-файлов; runtime validation task 41 записана в owning task.
- Reviewer GUI/editor QA не выполняет.

Применять текущий [review-orchestration](../../.agents/skills/review-orchestration/SKILL.md):
один read-only child на immutable SHA, Main единственный writer, без competing editor/tests.
Нет доступной telemetry — NOT_MEASURED; self-review помечать NON_INDEPENDENT.
Пилот завершён в объявленном объёме: три сравнения собраны, отсутствующие метрики не выданы за PASS.
Workflow остаётся Main + один read-only reviewer; обязательные исходные gameplay gates не менялись.

### Owner QA / blockers

Блокеров пилота нет; ручная gameplay/visual приёмка принадлежит исходным задачам и остаётся открытой.
Результат эксперимента не заменяет runtime/owner acceptance и не доказывает преимущество скорости.
