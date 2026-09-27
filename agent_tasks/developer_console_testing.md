# Developer Console Testing

Status: active — Stage 6 complete; Stage 7 convenience day/customer commands next.
Scope: specification only; implementation has not started.

## Goal

Extend the existing Developer Console under `res://addons/console/` with project-specific testing commands for Packages, Customers, Economy, Health and lifecycle scenarios.

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
- [ ] Stage 7 — Convenience day/customer commands.
- [ ] Stage 8 — Autocomplete/help.
- [ ] Stage 9 — focused GUT + one headless smoke.

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

## Completion criteria

The developer console can reproduce all required testing scenarios without direct gameplay-state mutation from the console callback, while existing Package, Customer, Wallet, Damage and Day services remain authoritative.
