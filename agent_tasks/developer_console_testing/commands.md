# Developer Console Testing — Command Contract

Artifact: **SUPPORT**  
Owner task: [Developer Console Testing](../developer_console_testing.md)

This file defines command grammar/behavior only. It does not own task status, implementation progress, or the next action.

Read this file only when implementing or modifying developer-console commands.

Sections preceding the planned extension describe the completed base command set. The extension below is proposed grammar for future implementation, not registered runtime commands.

## Targets

```text
self
target
#001
pkg:<package_id>
visit:<visit_id>
entity:<entity_id>
```

`<pkg>` means `#001`, `pkg:...`, or exact raw package_id.

---

## Package commands

### `pkg_list [active|all]`

Show package_id, active registration number, definition key/description, live/missing state, condition and linked visit.

Default: `active`.

### `pkg_info <pkg>`

Show:
- package_id / registration number;
- definition key/description/accounting value;
- live state;
- HP/max HP;
- registration/opening/damage/leaking;
- linked visit;
- Actual;
- Declaration;
- Disposition;
- Satisfaction;
- Complaint reason/outcome;
- settlement/money delta.

### `pkg_spawn <definition_key> [count=1] [receiving|self] [registered=0|1]`

Create Package instances from existing `DEF_Package`.

Rules:
- definition is resolved by `GameDefinition.key`;
- scene comes from existing `scene_variants`;
- reuse normal Package initialization;
- `receiving` uses Receiving/factory placement;
- `self` spawns in front of Player through a debug adapter but preserves the same initialization contract;
- generated package_id must be unique in the current World;
- `registered=1` uses domain registration logic, never direct field writes.

### `pkg_remove <pkg>`

Remove only the live physical Package Entity/Node.

Registry and CustomerVisit facts remain. This intentionally supports Missing/Lost/Fraud testing.

### `pkg_purge <pkg>`

Explicit cleanup for debug-created data.

May remove physical Package and related debug-created records only when doing so cannot erase committed settlement/complaint/history.

Unsafe purge -> explicit error.

### `pkg_register <pkg>`

Register a live Package without Scanner gesture while preserving the normal ledger and smallest-free-number contract.

Repeated registration is idempotent.

---

## Actual outcome vs Terminal declaration

Never merge these into one command.

### `pkg_actual <pkg> delivered|customer_refused|player_denied|not_resolved`

Force the factual CustomerVisit outcome through a debug Customer-domain adapter.

Requires a visit.

Does not write Terminal declaration.

### `pkg_declare <pkg> taken|refused|lost`

Emulate the Player's Terminal declaration through the existing declaration/settlement path.

Does not rewrite Actual except where the production declaration contract intentionally does so.

### Convenience aliases

```text
pkg_taken <pkg>             -> declaration TAKEN
pkg_lost <pkg>              -> declaration LOST
pkg_refused <pkg>           -> declaration REFUSED
pkg_delivered <pkg>         -> actual DELIVERED
pkg_customer_refused <pkg>  -> actual CUSTOMER_REFUSED
pkg_player_denied <pkg>     -> actual PLAYER_DENIED
```

Aliases reuse the same implementation.

---

## Visit commands

### `visit_create <pkg> [customer_key=default]`

Create a debug `CustomerVisit` for a Package without requiring a live physical Customer.

Use:
- stable package identity;
- accounting value;
- existing `DEF_Customer` policy;
- current day.

If a visit already exists, return it instead of creating another.

### `visit_info <pkg|visit:id>`

Display persistent visit/dispute state without requiring a live Customer Node.

---

## Complaint / approval commands

### Required production extension

`CustomerComplaint` must gain typed complaint reason at minimum:

```text
NOT_DELIVERED
DAMAGED
```

The reason belongs to the shared Customer domain, not debug-only state.

### `pkg_complaint <pkg> not_delivered|damaged [pending|resolve]`

Default mode: `pending`.

`pending`:
- create a complaint with typed reason;
- keep it unresolved.

`resolve`:
- create it if absent;
- immediately run normal adjudication/settlement while bypassing only the day-delay gate.

Repeated identical complaint is idempotent.
Conflicting reason returns an error.

### `complaint_resolve <pkg>`

Immediately resolve an existing pending complaint through the production outcome service.

Must not rewrite Actual or Declaration.

### `pkg_approve <pkg> [satisfaction=100]`

Create typed positive Customer feedback/approval.

Rules:
- Satisfaction range 0..100;
- default 100;
- approval does not automatically mean DELIVERED or TAKEN;
- future Reputation integration must be able to consume this fact;
- payment changes only if production lifecycle rules use that feedback.

---

## Economy commands

All mutations use `WalletService` plus journaled typed operations.

### `wallet_info`

Show:
- day;
- balance;
- penalties;
- current-day income/spending/penalties/closing balance;
- recent debug operations.

### `money_add <amount> [note]`

Journaled debug credit.

### `money_remove <amount> [note]`

Journaled forced debug debit.

This is not PURCHASE and may create debt.

### `penalty_add <amount> [note]`

Journaled manual/debug penalty:
- balance decreases;
- penalty total increases;
- typed reason is debug/manual, not LOST/PLAYER_REFUSAL/FRAUD.

### `penalty_remove <amount> [note]`

Compensating reversal:
- does not delete old MoneyOperation;
- refunds balance;
- reduces only reversible manual/debug penalty total;
- cannot silently reverse production package settlements.

Debug money operations must use unique operation IDs and remain visible in history.

---

## Health / life commands

### `health_info [target=self]`

Show:
- resolved Entity id/type;
- HP/max HP;
- depleted;
- C_Living;
- C_Death;
- control enabled if applicable;
- Package damage condition if applicable.

### `apply_damage <target> <amount> [generic|melee|impact|explosion|toxic|liquid]`

Create `DamageRequest.Operation.DAMAGE`.

Default damage type: generic.

Package damage must flow through normal Package destruction/debris/hazard lifecycle.

### `heal <target> <amount>`

Create `DamageRequest.Operation.HEAL`.

Works for any live Entity with `C_Health`, including Package.

If a living target is terminally depleted, return:

```text
ERROR target depleted; use reset
```

### `kill [target=self]`

Apply sufficient normal damage for Health depletion.

Never write `health.current = 0` directly.

Using kill on a Package means normal Package destruction.

### `reset [target=self]`

Only for an existing live living Entity.

Dedicated debug lifecycle reset must:
- restore HP to effective max;
- clear `depleted`;
- remove terminal `C_Death`;
- restore control/lifecycle flags;
- clear stale interaction/grab state when required for usable control.

Does not recreate an Entity already removed from World.

Destroyed Package recreation uses `pkg_spawn`.

---

## Recommended convenience commands

### `pkg_reset <pkg>`

For a still-live Package:
- HP -> max;
- Damage -> UNDAMAGED;
- leaking -> false.

Do not silently delete independent hazard effects.

### `day_info`

Show day index, phase and remaining Customer events.

### `day_next`

Request the next normal phase through the Day transition contract.

Do not mutate `C_DayCycle.phase` directly.

### `customer_next`

Force the next due visit when no active Customer is being serviced.

### `debug_targets`

List concise target handles for Player, Customers, Packages and useful destructible entities.

Do not dump every Component in World.

---

## Autocomplete

At minimum:
- command names;
- `self`, `target`;
- enum arguments for Actual/Declaration;
- complaint reasons;
- damage types;
- current Package definition keys for `pkg_spawn`.

Dynamic live Entity IDs do not need continuous autocomplete rebuild; use `pkg_list` and `debug_targets` for discovery.

## Release safety

Project-specific developer commands register only when:
- running a debug/development build, or
- an explicit project setting enables dev commands.

Production release default: disabled.

Generic addon console behavior is outside this task unless its existing command-registration API proves insufficient.

## Planned extension — 2026-10-02

Owner: [Developer Console Testing, Stages 10–15](../developer_console_testing.md). Gameplay additions: [R23 QA-01–QA-13](../roadmap_23_vertical_slice_validation/owner_qa.md).

### `help [command|group]`

- No argument: concise command groups, target syntax, built-in help discovery and examples of the main testing workflows.
- A command name: description, exact positional syntax, required/optional arguments, defaults, units/ranges, one working example, side effects and relevant eligibility restrictions.
- A group name: commands and examples for `packages`, `customers`, `economy`, `health`, `inventory`, `trader`, `npc`, `challenges`, `world`.
- Unknown subject: useful ERROR and available names; no gameplay state changes.
- Generate command listings/syntax from the registered project command metadata to prevent stale help. Distinguish ordinary gameplay actions from explicit debug overrides.
- Preserve the addon's existing `help`, `commands`, `commands_list` discoverability via project integration; retain `debug_help` as a compatibility entry to project help. Autocomplete registered command/group subjects where the existing API permits.

### Proposed command surface

These names/arguments are the starting specification. Confirm against current authoritative contracts during Stage 10 and update this table before implementation. `<npc>`/`<object>` use existing `target` or `entity:<entity_id>` resolution; `<visit>` uses `visit:<visit_id>` or the package's visit. Authored definitions use their stable keys, never scene node names.

| Area | Proposed commands | Required behavior |
| --- | --- | --- |
| Hunger | `hunger_info [self]`, `hunger_set <value>` | Display current hunger, range and active effects; validate value against authored bounds, use the authoritative hunger transition. |
| Inventory | `inventory_info [self]`, `inventory_give <definition_key> [count=1]`, `inventory_use <slot>` | Display occupied slots/IDs; reuse normal item creation, ownership, capacity and consumable-use contracts. Report full inventory or unusable item. Document slot indexing in help. |
| Trader | `trader_info`, `trader_open` | Display availability, authored offers and prices; request the existing interaction/UI, report phase/distance restrictions. |
| Orders/Quest | `order_info`, `order_place <definition_key> [count=1]`, `quest_info` | Reuse payment, eligibility, order creation and next-Morning fulfillment; show quest progress/conditions without raw stage writes. |
| NPC | `npc_info <npc>`, `npc_attack <npc> <melee|ranged> <slot> <victim>`, `nav_info <npc>` | Show visit/intent, selected profile, target, cooldown and NavigationAgent path/avoidance state; request an authored ability. At most three slots per attack kind; invalid/unavailable ability fails explicitly. |
| Challenges | `challenge_info <visit>`, `challenge_start <visit> <definition_key>`, `challenge_stop <visit>` | Show timer, condition, tasks and arrival/departure scope; use existing challenge lifecycle, mark explicit debug start/stop overrides in output. |
| Hazards | `hazard_info [target]` | Inspect live effects, remaining time, pending removal and owner-loss policy without deleting independent effects. |
| Persistence | `save_info`, `save_write <slot>`, `save_load <slot>` | Use the existing snapshot/restore contract. Restrict extension testing to explicitly named isolated debug slots; default gameplay save must not be overwritten. Explain load effects in help. |
| Debug presentation | `debug_ui <on|off>`, `debug_markers <on|off>` | Toggle existing debug presentation and optionally the hidden map annotation for this session. Do not write visibility back to the authored scene; above-client status joins the shared debug toggle. |
| Valves/buttons | `progress_info <object>`, `progress_set <object> <value>` | Inspect normalized progress; route a debug adjustment through Entity glue so rotation and `progress_changed` agree. Reject unsupported targets/ranges. |
| Corpse/meat | `corpse_info <object>`, `meat_spawn [self]` | After QA-04 exists, inspect corpse hit progress/conversion state and create the authored edible placeholder through the normal factory. Validate actual conversion using existing damage commands/weapon interaction, not duplicate console logic. |
| Client modes | Extend `visit_create` with an optional authored behavior key; extend `visit_info` | After QA-07/08 exist, select/test immediate-number and first-approach-dialogue modes; report mode and whether its once-per-visit action has occurred. Preserve existing `visit_create` invocation compatibility. |

Info commands are read-only and concise; mutation commands report `OK`/`ERROR`, resolved target and committed result. Never implement a separate console copy of trading, combat, hunger, challenge, corpse or persistence rules. Retain production-default disabling and stable target resolution.

### Testing workflows to document in help

- Food: create/give food, inspect hunger and inventory, consume, inspect the committed changes.
- Trader: inspect phase/availability, interact, place a valid paid order, advance through the normal Night/Morning transition and inspect fulfillment.
- Client: create visit, inspect mode/challenge, observe announcement or first approach, inspect arrival-to-departure completion.
- Combat: inspect NPC abilities, request a valid attack, kill NPC, apply several eligible knife/hammer hits to corpse, consume resulting meat.
- Interactive object: inspect/set progress, observe rotation and emitted signal; reset/restore through existing contracts.
- Persistence: write an isolated slot, change state, load the same slot and inspect restored authoritative state.

Help must show only currently registered commands as available. Until a corresponding gameplay feature exists, its proposed command remains a documented dependency rather than a success-shaped stub.
