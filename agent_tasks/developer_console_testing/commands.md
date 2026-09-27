# Developer Console Testing — Command Contract

Read this file only when implementing or modifying developer-console commands.

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
