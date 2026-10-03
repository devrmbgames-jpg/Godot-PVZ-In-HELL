# Developer Console Testing

Status: **OWNER_QA**

Priority: **LOW** — дополнительная задача; выполнять после основных исправлений игрового QA.

## Task state

### Goal
Extend the existing Developer Console with project-specific testing commands for Packages, Customers, Economy, Health and lifecycle scenarios without creating a second gameplay authority.

Extension requested by owner: cover expanded gameplay and QA-01–QA-13, and expose discoverable `help` with command syntax/examples.

Дополнение владельца: исправить прокрутку открытой консоли. Расширение команд, справка и прокрутка составляют одну дополнительную задачу низкого приоритета.

### Constraints / acceptance
- `addons/console/` stays generic; project-specific commands live under project code.
- Commands call authoritative domain/services/contracts instead of mutating ECS state directly.
- Customer actual outcome and Terminal declaration remain separate concepts.
- Debug commands are disabled for production by default.
- Detailed command grammar is supporting specification: [commands.md](developer_console_testing/commands.md).
- При открытой консоли длинный вывод можно прокручивать колёсиком мыши и полосой прокрутки; сохранить доступные PageUp/PageDown и ввод команд. События консоли не должны одновременно управлять игроком.

### Milestones
- [x] Stage 1 — command infrastructure / target resolution.
- [x] Stage 2 — package create/remove/register flows.
- [x] Stage 3 — actual package outcome / Terminal declaration.
- [x] Stage 4 — customer visit controls.
- [x] Stage 5 — complaint / approval flows.
- [x] Stage 6 — economy operations.
- [x] Stage 7 — health / lifecycle / world helpers.
- [x] Stage 8 — autocomplete/help.
- [x] Stage 9 — focused validation and completion review.
- [x] Stage 10 — audit current gameplay contracts; grouped `help [command|group]`, preserve built-in help and `debug_help` compatibility.
- [x] Stage 11 — Hunger, Inventory, Trader, Orders and Quest commands.
- [x] Stage 12 — NPC attacks/navigation, visit behavior, Challenges and Hazards commands.
- [x] Stage 13 — isolated persistence testing, world/client debug presentation and interactive progress commands.
- [x] Stage 14 — corpse/meat and new client modes after their R23 QA implementations exist.
- [x] Console scrolling — reproduce inability to scroll while open; restore output scrolling and verify focus/input behavior.
- [x] Stage 15 — focused regression validation, updated command contract and completion review.

### Decisions
The console is a debug frontend only. Domain services/contracts remain authoritative; command handlers must not become alternate business logic.

The addon already owns generic `help`; integrate project help through project-side registration without editing addons or losing built-in discovery. Proposed extension grammar lives in the supporting contract and is not a claim that commands already exist. Stage 14 depends on the relevant [R23 owner QA tasks](roadmap_23_vertical_slice_validation/owner_qa.md).

### Current

Stages1–15 implemented: grouped registry help, scrolling/focus,28 new commands over current gameplay APIs, live visit option and diagnostic targets. Next: final Windows export, then owner full-day/visual/UI QA. Addon untouched; production defaults preserve disabling. Persistent debug slots are Morning-only and require idle interactions.

### Validation
2026-10-02 extension task recording: project structure validator and changed-document diff check PASS; gameplay/command implementation and runtime validation remain pending.

Historical validation for Stages 1–9 only; extension Stages 10–15 have not been run:
- Project structure/static validation: PASS.
- Godot: 4.7.1 stable, headless.
- Focused GUT: GUT 9.7.1, 4/4 tests passing, 93 assertions.
- Headless smoke: `utils/run_smoke.ps1 -Name developer_console` — PASS.
- The runtime validation checkout included the repository-pinned GECS submodule.
- No rendered/visual Godot run was performed.

### Owner QA / blockers
Ручные проверки и результаты игроков: [сценарий QA](../qa_tasks/developer_console.md).

Игровая приёмка ожидается; перенос не означает успешного прохождения. Реализация и автоматические доказательства остаются в этой задаче.

---

## Goal

Extend the existing Developer Console under `res://addons/console/` with project-specific testing commands for Packages, Customers, Economy, Health and lifecycle scenarios.

Also cover Hunger/Inventory, Trader/Orders/Quest, NPC/Challenges/Hazards, persistence and the new R23 QA mechanics. Implement the proposed [extension and help contract](developer_console_testing/commands.md#planned-extension--2026-10-02).

The console is a debug frontend, never a second gameplay authority.

Detailed command contract: [commands.md](developer_console_testing/commands.md).

## Architecture

Keep `addons/console/` generic. Do not put Package/Customer/Wallet/Health gameplay logic into `addons/console/console.gd`.

Project integration should live under `content/debug/`:

```text
Console autoload
    -> DeveloperConsoleCommands
    -> DebugTargetResolver
    -> thin debug adapters
    -> existing domain services
```

No new scheduled `S_*` is required for console commands.

### Required boundaries

- Damage/heal/kill use `DamageRequestService`.
- Money uses `WalletService` and journaled typed operations.
- Customer actual outcome and Terminal declaration stay separate.
- Package lookup uses stable identity or active registration number, never Node names.
- Package creation reuses existing `DEF_Package`, scene variants and initialization/factory contracts.
- Debug commands must return explicit `OK` / `ERROR` output with useful context.
- Project-specific commands must be disabled by default in production release builds.

## Target grammar

Shared target resolver:

```text
self                  # live Player Entity with C_PlayerInputController
target                # current Player C_Interactor.target
#001 / #1             # active Package registration number
pkg:<package_id>      # stable Package identity
visit:<visit_id>      # persistent CustomerVisit
entity:<entity_id>    # live GECS Entity
```

Package-specific commands may also accept an exact raw package_id.

Registration-number lookup resolves active records only.

## Required feature groups

### Package

- spawn Package by definition key;
- remove physical Package without erasing registry/history;
- explicit debug purge for safe debug-created state cleanup;
- register Package without Scanner gesture;
- list and inspect Package state.

### Customer outcome / Terminal declaration

These are separate commands and separate facts.

Actual outcome:
- DELIVERED
- CUSTOMER_REFUSED
- PLAYER_DENIED
- NOT_RESOLVED

Terminal declaration:
- TAKEN
- REFUSED
- LOST
- NONE

Never replace both layers with one generic `status` mutation.

### Complaints / approval

Support typed complaint reasons at minimum:
- NOT_DELIVERED
- DAMAGED

Support positive Customer approval as a typed feedback/fact rather than only mutating Satisfaction.

If production contracts do not yet expose these reasons, implementation must extend the shared Customer domain first; debug-only shadow state is forbidden.

### Economy

Support:
- credit balance;
- forced debit;
- manual/debug penalty;
- compensating penalty reversal.

All operations stay journaled. Reversal is a compensating operation, never deletion of history.

### Health / lifecycle

Support:
- health inspection;
- heal;
- apply damage;
- kill;
- reset/revive a live living Entity.

Kill/damage never write HP directly.
Heal does not resurrect terminally dead actors.
Reset is a separate lifecycle operation.
Destroyed Package recreation uses Package spawn, not living reset.

## Recommended convenience commands

Also include when implementation reaches this task:

- Package reset for a still-live damaged Package;
- day info;
- request next day phase;
- force next due Customer visit when valid;
- list convenient debug targets.

These commands must still route through existing gameplay boundaries.

## Output contract

Example success:

```text
OK heal self
hp=35.0 -> 60.0 / 100.0
```

Example failure:

```text
ERROR pkg_declare #009
no CustomerVisit for package base_supply:debug:17:bottles
hint: visit_create #009
```

No silent failures and no bare boolean result as user-facing output.

## Implementation progress

- [x] Stage 1 — command registrar, target resolver, uniform output formatting.
- [x] Stage 2 — read-only diagnostics.
- [x] Stage 3 — Package spawn/remove/register.
- [x] Stage 4 — Customer outcomes/feedback/complaints.
- [x] Stage 5 — Wallet/penalty operations.
- [x] Stage 6 — Damage/kill/heal/reset.
- [x] Stage 7 — Convenience day/customer commands.
- [x] Stage 8 — Autocomplete/help.
- [x] Stage 9 — focused GUT + one headless smoke.

## Implementation order

1. Command registrar + target resolver + uniform result formatting.
2. Read-only diagnostics.
3. Package spawn/remove/register.
4. Actual/declaration/customer feedback/complaint commands.
5. Wallet/penalty debug operations.
6. Damage/kill/heal/reset lifecycle.
7. Convenience day/customer commands.
8. Autocomplete/help.
9. Focused GUT coverage + one headless smoke near completion.

Commit each coherent stage separately. Do not launch rendered/visual Godot without explicit user approval.

## Validation

GUT:
- target grammar/resolution;
- package lookup by stable id and active registration number;
- invalid/freed targets;
- package spawn/remove/register;
- Actual vs Declaration separation;
- complaint reason/resolve semantics;
- approval semantics;
- wallet debug operations, idempotency and reversal;
- heal/damage/kill/reset lifecycle.

Headless smoke:
- spawn/register Package;
- damage/heal Package;
- create visit;
- set Actual/Declaration independently;
- create/resolve complaint;
- wallet credit/debit/penalty/reversal;
- kill/reset Player;
- remove spawned Package;
- verify expected OK/ERROR results.

Stage 9 result:
- focused `test_developer_console.gd`: 4/4 tests, 93 assertions, PASS;
- `developer_console` headless smoke: PASS;
- project structure/static validation: PASS.

Extension validation (Stages 10–15, pending): help enumeration/specific-command examples/unknown subject; built-in command preservation; typed invalid/freed targets; inventory capacity and consumable use; food/hunger; legal Trader/Quest/Order transitions; NPC attack slot limits and cooldowns; visit-mode once-per-visit behavior; challenge arrival/departure lifecycle; isolated save/load without ordinary-slot overwrite; valve signal/progress; one-time corpse conversion and edible meat. Use relevant focused tests once and one relevant headless smoke near completion, rather than a full game run after each command. Commands requiring ordinary interaction eligibility should return an explanatory ERROR when unavailable.

## Completion criteria

The developer console can reproduce all required testing scenarios without direct gameplay-state mutation from the console callback, while existing Package, Customer, Wallet, Damage and Day services remain authoritative.

### Дополнение R24 / QA-05

Реализовано `debug_hud [on|off|toggle]`: отключает экранные отладочные панели и статусы над клиентами, оставляет обычный HUD и игровые эффекты. Без аргумента переключает состояние. Команда включена в `debug_help`, `commands_list` и автодополнение. GUT7/7,115 assertions; расширение остальных команд/help и прокрутка остаются LOW priority.

### Active help / scroll milestone (recorded before implementation)

Addon Console builds a scroll-enabled RichTextLabel and owns PageUp/PageDown but opening only grabs LineEdit focus: it never releases captured game mouse. Project-owned presentation adapter listens to open/close, preserves/restores mouse and underlying modal UI focus, permits wheel/scrollbar with visible pointer. Keep addon input/key behavior and generic help callable; wrap help with optional registered command/group lookup, derive syntax/description from Console metadata and keep debug_help compatible. Adapter lifetime restores the previous help registration. Focused actual-console routing/long-output/headless checks justified; no rendered run or broad suite.

### Help / scroll validation

Project adapter restores visible mouse on open and previous mode/focus on close; output wheel/scrollbar and existing PageUp/PageDown remain available. `help [command|group]` derives syntax/descriptions from live registry, includes built-in instructions, debug_help compatible. Addon untouched. Focused actual-console long-output/help checks2/2,14 assertions (`.export/console-presentation-gut.log`); no broad/runtime/visual rerun. Full extended command metadata/examples follow Stage11–14 implementations.

### Active extended-command contract (recorded before implementation)

Audit: HungerService owns bound transitions; InventoryService owns grants/transfers/use. CommerceService/Panel own orders/payments/UI, TraderCatalogService owns hours/catalog. NpcAttackService accepts kind/index over R_CombatTarget; debug failure restores previous target. ChallengeService owns arm/activate/cancel, debug start may replace only inactive unconsumed authored challenge. Valve debug adjustment goes through Entity glue and retained progress owner, rejects active/completed sessions; no duplicate completion effects. NPC remains now spawn edible pickups immediately: corpse_info reports release state, no fictitious corpse hit meter.

Persistence is Morning-snapshot only: save_write/load require named alphanumeric isolated user://debug_slots slot, Morning, no live customer/modal/grip/active challenge; never touch production autosave. Preserve normal snapshot validation/restore. visit_create optional arrive0|1 requests live queued visit using existing authored customer_key; old invocation retains finished accounting-only visit. Update proposed grammar to actual contracts before release. One relevant extended-console GUT surface near stage completion, no broad repeat after M2.

### Extended commands implementation / validation

28 commands: hunger/inventory, profile trading and paid buy/courier/orders, quests, NPC3+3/navigation, challenge start/cancel/diagnostics, hazard lifetime, isolated Morning saves, HUD/markers, valve progress and edible remains. Info is read-only; writes go through existing owners plus narrow explicit APIs. Optional parser blanks normalized; visit_create arrive preserves legacy accounting-only invocation. Help shows live syntax/defaults/restrictions/examples/workflows.

Initial bounded GUT:22 existing regressions PASS (console4, presentation2, NPC attacks16); three new fixture failures used pre-initialization component references, corrected to actual Entity components. Six new command/parser cases PASS52 (`.export/console-extension-parser-gut.log`). No broad rerun. Independent review R7/P2 OPEN: Morning restore allowed push/cart. FIXED: reject all captures above HANDS and authoritative Push/CartDriver links before writes/loads. Changed regression alone1/1,14 (`.export/console-extension-review-fix.log`); reviewer confirmed FIXED, no other material findings.

Integrated actual-main developer_console smoke PASS (`tests/artifacts/developer_console-20261003-093440520.log`): real parser/help, food consumption, trader/quest/order projection, runtime markers, named Morning snapshot roundtrip, legacy package/accounting/health operations. Fixture disables automatic owner autosave loading and deletes only its own isolated slot. No rendered/gameplay acceptance claimed. Structure/diff PASS; formatter SKIP (unavailable). Windows exports follow; last full suite remains major M2:426/426,3375.

### Published owner QA build

Windows9d06320c main/test exported; both actual-scene120-frame headless startup PASS. Launch `.export/LATEST.cmd` / `.export/TEST_LEVEL.cmd`. Main: `.export/windows/20261002-234243Z-9d06320c-gameplay-console-main/PVZInHell.exe`; test: `.export/windows/20261002-234409Z-9d06320c-gameplay-console-test/PVZInHell.exe`. Next: owner full-day main scene walkthrough and targeted QA checklists. No full rendered/gameplay/audio acceptance claimed. Master unchanged, user main/project/addons edits preserved.


## R33: выносливость

`stamina_info [target=self]` читает запас/максимум, running, hold/toggle, множитель расхода груза, таймер восстановления и exhaustion. `help stamina_info` и `help health` включают команду; обычный HUD показывает шкалу, `debug_hud on` добавляет условия/таймер. QA: пробежать, остановиться, сверить восстановление; повторить с грузом и режимом переключения. Чтение через открытую консоль прекращает переключённый бег по правилу input focus.


### 2026-10-03 — исправление неполного help

`help` без аргументов теперь после встроенной справки выводит все публичные команды из живого Console registry через commands_list, с аргументами и описаниями. `debug_help` наследует тот же вывод; detailed command/group help сохранён, hidden commands исключены. Regression проверяет реальный parser, позднюю регистрацию, публичные имена, описание/аргументы, hidden и alias; focused test_console_presentation3/3,101 assertions PASS (.export/console-help-regression-gut.log). Полный suite/runtime/export не повторялись для локальной правки. Owner checklist qa_tasks/developer_console.md обновлён; addon не менялся.
