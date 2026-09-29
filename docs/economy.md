# Wallet and daily results (R10)

`DaySession` owns one `C_Wallet` alongside `C_DayCycle`. `WalletService` is the synchronous write boundary; no UI writes money. `S_WalletDay` runs after `S_DayPhase`, marks a shift completed once on Evening/Night, and opens a new daily result without resetting the wallet or journal. Evening transactions belong to the same day; `closing_balance` remains provisional until that day ends.

## Monetary operations

Money uses whole integer units (no floating point). `MoneyOperation` carries producer-owned stable `operation_id`, typed `reason`, positive-or-zero magnitude, original `day_index`, and optional `settlement_id`. `submit()` resolves the live session and applies atomically. `apply()` is the same deterministic boundary with explicit wallet/day, used by tests. There is no yield between validation and mutation.

Payment credits the wallet. Purchase debits only with sufficient funds; a rejected purchase leaves no journal entry and may be retried. Explicit developer operations use separate `DEBUG_CREDIT`, `DEBUG_DEBIT`, `DEBUG_PENALTY` and `DEBUG_PENALTY_REVERSAL` reasons; they remain in the same journal and never masquerade as package outcomes. Package buyout and mandatory penalties may create debt. The next-morning missed-registration audit reuses the existing `LOST` settlement (120% of accounting value) and the visit identity, so rerunning the audit cannot double-charge the package. No silent clamping: malformed requests and balances outside ?1,000,000,000 units are rejected. UI receives explicit COMMITTED, DUPLICATE, INSUFFICIENT_FUNDS, INVALID or CONFLICT status.

`DEF_Economy` authors delivery payment and settlement percentages: voluntary buyout 100%, Lost 120%, player refusal 150%, confirmed fraud/complaint 200%. `DEF_Package.accounting_value` is independent of resale value and shown in Terminal. `package_settlement()` builds a typed operation, rounding fractional units upward. R11 decides eligibility/confirmed outcomes and must call submit; this layer never adjudicates complaints or automatically charges on parcel damage.

Both operation identity and nonempty settlement identity are deduplicated across all days. Retrying an identical historical result is a no-op; reusing its identity with changed reason, amount, original day or settlement is a conflict. Producers must reuse a durable outcome identity across delivery/complaint/return retries. Different operations for legitimately separate outcomes need separate IDs. Morning Return does not reverse a committed settlement. Accepted requests are copied so caller mutation cannot change financial history.

## Read/save contracts

`C_Wallet.balance`, cumulative `penalties`, `completed_days`, accepted `operations` and `daily_results` are the persistent authority. Daily income, purchase/buyout spending, penalties and closing balance are separate from cumulative state. Penalties include Lost, player refusal, confirmed fraud and outstanding manual debug penalties; compensating debug-penalty reversals reduce the penalty total without deleting historical operations. Buyout/debug debit are spending, debug credit/reversal are credits. Typed reasons also supply future reputation hooks.

Terminal reads balance and current-day totals. `WalletService.snapshot()` returns a detached deep copy for readers/save preparation. R21 must persist and restore the complete exported wallet state, including operation/settlement identities and daily completion flags, together with the day cycle; restoring only balance loses idempotency. Disk persistence is outside R10.

Validation: `tests/gut/test_wallet.gd` and `tests/smoke/wallet_smoke.tscn` cover calculation, idempotency, purchase rejection/retry, debt, day totals, detached state and main-scene day scheduling.

2026-09-27 validation: Godot 4.7.1, 7/7 GUT tests (42 assertions); wallet headless smoke PASS after user-authorized correction/rerun of the success marker. Structure validation and diff whitespace check PASS. Optional formatter unavailable; visual validation not run.
