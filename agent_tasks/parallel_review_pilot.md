# PVZ: параллельный read-only reviewer — пилот

Status: **IN_PROGRESS**

## Task state

### Goal

Проверить скорость и качество Main + Reviewer на 2–3 существенных
checkpoints без вмешательства GitHub CI и без одновременных авторов кода.
Исходная ветка `dev`, SHA `6438b85665eaf55e602319f83830dfc79d44a297`.

### Decisions / acceptance

- [x] Main единственный writer/Review Manager; один child reviewer read-only.
- [x] Review pinned `BASE_SHA..TARGET_SHA`, без живого Godot и worktree writes.
- [x] P0/P1/P2 блокируют DONE до FIXED, P3 можно обоснованно отложить.
- [x] Два repair rounds максимум, иначе BLOCKED.
- [x] Примеры промптов и ссылки опубликованы в `docs/`.
- [x] Native read-only reviewer запущен из Codex; Main продолжил независимую сверку logs/SHA.
- [ ] Сравнены 2–3 значимых checkpoint с серийным режимом.

### Current

Implementation policy применена к первому task-41 checkpoint; следующий шаг —
сравнить ещё representative checkpoints. На этапах измерить review overlap,
elapsed time, замечания и доступные token usage.
Никаких дополнительных очередей / Manager Agent / GitHub workflows.

2026-10-09: Main запустил один native read-only reviewer для task 41 на полном
`857ec02d7703eab840dbf496730be48d29294d99..da636b0c5c46cd82260e58db1a508ca00f531fb8`.
Результат собран и triaged в owning task; benchmark 2–3 checkpoints ещё не завершён.
Статусы ошибок и исправления принадлежат task 41, отдельная очередь не создаётся.

### Validation

- Static inspection: instructions/role contract and frontmatter.
- Native Codex reviewer для task 41 выполнен; точные findings/validation — в owning task.
- NOT_MEASURED: review overlap и сравнительная эффективность 2–3 checkpoints.
- NOT_RUN: Godot/GUT для policy-файлов; runtime validation task 41 записана в owning task.
- Reviewer GUI/editor QA не выполняет.

### Owner QA / blockers

Остаётся сравнить 2–3 representative checkpoints и записать измерения эффективности.
Выполненный bounded review не завершает pilot и не является полной приёмкой task 41.
