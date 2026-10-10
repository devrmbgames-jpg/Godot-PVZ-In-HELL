# Refactoring v2.64 — Code Style: gameplay services, economy, inventory, persistence

Status: **IN_PROGRESS**

Зависимости: 63_style_interaction_combat_motion.md.

## Goal

Пройти оставшийся доменный сервисный код и сделать его роли/операции читаемыми без повторного архитектурного рефакторинга.

## Scope

- hazards/challenges/quests/hunger/receiving/packages/loot;
- economy/commerce/inventory;
- persistence/save/codec;
- input/settings/debug project-owned services;
- остальные доменные helpers из `content/domains/*/{services,rules,solvers,presentation}/**` и соответствующих roles в `content/shared/` по manifest задачи 61.

## Focus

- explicit operation names;
- typed transaction/result values;
- idempotency comments только там, где причина неочевидна;
- pure calculations отделены визуально от mutations;
- serialization code объясняет schema/compatibility intent, а не каждую строку;
- никаких новых generic Manager/Util/Service abstractions ради style cleanup.

## Acceptance

Style gate PASS по всему назначенному manifest scope, не покрытому предыдущими задачами.
Parser PASS.

## Current

Full manifest72 style PASS; native MCP path-bound compilation72/72, no diagnostics.
CLI ParseChanged PASS: `.artifacts/godot_agent/parsechanged-20261010-090220872` logs.
Source edits saved through MCP. Typed placement receipts, snapshot data, relationship
state and transaction outcomes retain public APIs, schema10 keys, stable IDs and numeric
values. Conditional branches preserve optional lifetime boundaries and mutation order.
No authored scenes/resources or third-party addons rewritten.

Profile GUT PASS:13 suites,215/215 tests,2095 assertions,28.582s; stderr empty.
Logs: `.artifacts/godot_agent/gameplay64_gut.{stdout,stderr}.log`.
Headless write plus fresh-process restore PASS for night_persistence,
safe_loot_placement and furniture_arrival (20261010-190333 through190354 logs
under `tests/artifacts/`). Strict architecture/domain/dependency/structure PASS;
prior task61–63 full style PASS. No rendered QA claimed.

Review: REVIEW_PENDING immutable checkpoint; collect before DONE. Tasks65–66 required.

## Validation

Style gate + parser; persistence/economy tests только при semantic restructuring.
