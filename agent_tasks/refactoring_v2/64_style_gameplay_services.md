# Refactoring v2.64 — Code Style: gameplay services, economy, inventory, persistence

Status: **PLANNED**

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

## Validation

Style gate + parser; persistence/economy tests только при semantic restructuring.
