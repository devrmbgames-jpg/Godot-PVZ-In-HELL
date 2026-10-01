# Current Work

Active: [R21 Night / Persistence / Next Day](agent_tasks/roadmap_21_night_persistence_next_day.md).

R17 `4615d3b3`: simple NPC melee/ranged 3+3 variants and animation hooks. R18 `86f91acc`: reversible Hunger/perception/debug. R19 `c11dea8b`: owned inventory and consumables. R20 backend `9da353db` plus completed integration: physical NavigationAgent Trader, atomic purchases, paid next-Morning order records, refusal quest using actual outcomes and debug deadlines/tasks. R20 final GUT 73/73 (662 assertions), strict evening main walkthrough and structure/diff PASS; separate read-only review has no material findings. Owner rendered walking/gamepad/balance QA remains in task files.

R21 foundation implemented: closed primitive snapshot/atomic slot, Night gate/retry and startup restore, typed persistent records, stable identities, all-old-bindings-first ownership/slot/cart restore, anchor/ink/quest refs, physical paid-order receiving, debug save/error/retry/task UI. GUT 15/15 (114 assertions), latest strict Night save/restart/Morning smoke and structure/diff PASS. Separate review R1–R6 FIXED and R4–R6 rechecked. R21 remains IN_PROGRESS: next physical Morning refusal return, relationship-role/capacity validation and broader reset/multi-day persistence regressions, then final feature review.

Goal remains active. Preserve user config, main/schedule resaves, addons/gecs and unrelated untracked UIDs. R21 authored main patch: tests/artifacts/r21_authored.patch; stage exact own files. Config limits have not blocked work.
