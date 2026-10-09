# Refactoring v2.24 — Economy, Inventory и Commerce

Status: **DONE**

Зависимости: [23_hazards_receiving_loot.md](23_hazards_receiving_loot.md), [13_customer_outcomes.md](13_customer_outcomes.md).

## Goal

Проверить крупные transaction-oriented services и не перенести их в Systems без причины.

## Scope

- `WalletService`;
- inventory services;
- commerce/order purchasing;
- food/effects;
- day summary/economy progression.
- existing Trader Profile/catalog authoring: выбрать DEF_TraderProfile единственным assortment source, перенести legacy inline catalog в inline/shared Profile и удалить fallback/all callers в том же slice.

## Direction

Transaction API с idempotency (`submit/apply/purchase/transfer`) обычно остаётся Service.
Регулярный day/frame progression должен принадлежать System/Observer.
Derived calculations могут стать Rules/Calculation.

## Acceptance

Сервисный слой экономики остаётся явным и синхронным.
Нет scheduled clock внутри transaction service.
Idempotency operation IDs и save-visible semantics не изменены.
Два existing Trader variants используют разные Profiles без нового runtime-кода. Legacy catalog/profile dual path закрыт; unrelated terminal C_Commerce catalog не становится shop authority.

## Validation

Wallet/inventory/commerce профильные tests + parser.

## Current / Next

DONE 2026-10-08. Далее [25 — Persistence и remaining services](25_persistence_remaining.md).

- `DEF_TraderProfile` is the only Trader assortment/schedule source. Removed `C_Trader.catalog`, Profile fallback and all old callers. The authored trader scene already selected `def_trader_default`; deleting its unused three-item array preserves the actual four-item offers. The isolated inline-commerce fixture now authors its own Profile with the same two offers and delivery disabled.
- Pure `TraderCatalogRules` and UI `CommercePanelFactory` replace the two mixed-role Service names/files, retaining both script UIDs. All runtime, debug, action, UI, test and smoke callers migrated; no compatibility aliases. Quest authoring reports missing required Trader Profile; optional quest configuration still disables only the quest.
- Two existing shared Profiles (general/medical) drive actual purchases, day availability and distinct offers on the same runtime role without new variant code. Regression also proves the terminal C_Commerce catalog cannot authorize or deny a Trader offer.
- Reviewed Wallet ledger transactions/daily result aggregation, Inventory R_OwnedBy transfer/use/drop, food/protection commands, correlated healing completion and Commerce/FurniturePlacement preparation/payment/receipts. Services remain explicit operations with preserved idempotency, prices and saved IDs. S_WalletDay remains the scheduled day-summary owner; WalletService.sync_day is an explicit idempotent day operation with no elapsed-time clock or World traversal.
- Inventory death completion now captures WeakRef plus exact Component identities. A freed typed Entity bound directly to Callable fails argument validation before callback guards execute; resolving inside the callback avoids that error. Removed-owner and cancelled-terminal-context regressions pass; disabled registered owners still receive terminal cleanup. The broader audit is explicitly assigned to task 26.
- Inventory smoke now follows the current CharacterBody player, actual authored batch limit, PhysicsBody pickup, selection/Use grid and compact HUD contract. Original ownership, quantities, effects, protection refusal, modal lifetime, full diagnostic content and death assertions retained. Trader purchase smoke runner now executes both write and restore phases.

## Validation evidence

- Godot parser **21 changed files PASS**, final adapted Inventory smoke **1 file PASS**; zero failures/warnings in the parser gate. Headless import refreshed moved UID/global-class paths; its known editor-addon exit resource noise is not counted as a clean parser test.
- GUT `refactoring_v2_24_corrected_gut.log`: **96/96, 1011 assertions PASS**, nine Wallet/Inventory/UI/Commerce/Trader/Profile/Quest/current-format snapshot/remains scripts; clean exit. Initial 95/96 run meaningfully reproduced the freed typed-Callable argument error; WeakRef completion fixes it without suppressing errors.
- Headless trader purchase write **PASS** (`trader_purchase-write-20261008-143057877.log`) and independent restore/replay **PASS** (`trader_purchase-restore-20261008-143107013.log`). Main-level Inventory targeting/pickup/consumption/modal/death smoke **PASS** (`inventory-20261008-143748233.log`). Intermediate stale fixture casts/UI assumptions were corrected against current scene contracts; no authored gameplay changes.
- Architecture **PASS** (2 remaining findings assigned to 25), structure, persistence baseline and roadmap preflight **PASS**. Original moved UIDs retained; no old class/path callers or inline C_Trader catalog remains. Current schema 3 unchanged; no old-save migration.
- Acceptance **PASS**. No rendered gameplay or subjective visual QA; no required owner QA for this behavior-preserving architecture slice.
