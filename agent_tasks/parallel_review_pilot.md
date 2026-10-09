# PVZ: параллельный read-only reviewer — пилот

Status: **READY_FOR_PILOT**

## Goal

Проверить скорость и качество Main + Reviewer на 2–3 существенных
checkpoints без вмешательства GitHub CI и без одновременных авторов кода.
Исходная ветка `dev`, SHA `6438b85665eaf55e602319f83830dfc79d44a297`.

## Decisions / acceptance

- [x] Main единственный writer/Review Manager; один child reviewer read-only.
- [x] Review pinned `BASE_SHA..TARGET_SHA`, без живого Godot и worktree writes.
- [x] P0/P1/P2 блокируют DONE до FIXED, P3 можно обоснованно отложить.
- [x] Два repair rounds максимум, иначе BLOCKED.
- [x] Примеры промптов и ссылки опубликованы в `docs/`.
- [ ] Настоящий параллельный pilot подтверждён в Codex/VSCode.
- [ ] Сравнены 2–3 значимых checkpoint с серийным режимом.

## Current / Next

Implementation policy готова; следующий шаг — запустить реальную Feature
по примеру №1 из `docs/ai_prompt_cheatsheet.md`. На этапах измерить review
overlap, elapsed time, замечания и доступные token usage.
Никаких дополнительных очередей / Manager Agent / GitHub workflows.

## Validation

- Static inspection: instructions/role contract and frontmatter.
- NOT_RUN: реальный native Codex concurrent reviewer в этой среде GitHub-коннектора.
- NOT_RUN: Godot/GUT — gameplay-код не менялся.
- Reviewer GUI/editor QA не выполняет.
