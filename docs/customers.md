# Customers, physical delivery and disputes (R11)

`DaySession/C_CustomerFlow` owns persisted `CustomerVisit` and `CustomerComplaint` resources. Records contain stable visit/customer/package IDs and authored policy, never Node references. Live `Package -> Customer` binding is exclusively `R_AssignedTo`; the record's package ID is the durable RequestedPackage contract and displayed registration numbers never establish ownership.

## Schedule and physics

`DEF_CustomerSchedule` maps each receiving batch to three immediate visits (books, glass, clothes) and one equipment visit delayed ten days. Other packages have no arrival event. `-1` delay explicitly disables an event. Thus normal days have three events and day eleven onward four; late and never-requested shipments retain their physical entities and reserved numbers. Customer identities include the supply day, so recurring recipient labels do not conflate distinct customers.

`S_CustomerFlow` schedules one customer at a time, before `S_DayPhase`, and owns `remaining_customer_events`. Structural work runs through its command buffer. Missing/unloaded customers and all terminal/death/timeout paths finish events. No customer completion deletes unrelated packages or declares terminal results. Session Resources are local to each main-scene instance to prevent shared mutable histories.

`E_Customer` is thin CharacterBody3D engine glue. `CustomerMotionService` owns body velocity and uses `move_and_slide`; gameplay systems write only destination/intents. Entry and Waiting markers belong to the physical counter scene. Movement is a short direct authored path, without navigation/pathfinding. Blocked approaches have an explicit timeout; leaving and aggression have bounded duration. Dialogue and OptionalFitting have a typed `enter_service_phase` hook and retain the patience timeout. R12/R17 own full dialogue/combat; R11 aggression is a visible state/hook, not an implemented attack.

## Player flow

Start the shift at its console. The customer approaches, greets and states the registered order number; F on the customer repeats the request after scanning an initially unregistered order. Place exactly one released box on the green DeliveryCounter and press F. The Area3D overlap, registration, stable identity and live AssignedTo must all agree. Missing, multiple, unregistered, wrong, unassigned, destroyed and held packages have distinct rejection feedback.

Damaged/opened flags remain separate; customer policy may accept with reduced Satisfaction/payment or voluntarily refuse. An accepted parcel leaves the world only after explicit confirmation. Refused parcels stay physical. Arrival, timeouts and terminal declarations never fetch or teleport storage boxes.

Terminal has visit selection and separate actual/declaration display. Its Taken/Refused/Lost buttons submit closeout commands. An initial false Taken is allowed and preserved. Committed declarations cannot be overwritten; repeated commands are idempotent. Explicit Deny records player refusal before a declaration, so lying afterward does not erase the denial fact/reputation reason. Missing/denied parcels retain their registration until an explicit warehouse departure.

## Money, refusal and complaints

R10 remains the only monetary writer. Delivered + Taken pays the authored delivery payment scaled by Satisfaction. Lost settles 120%, honest player refusal 150%. Revealed concealed/fraudulent refusal settles 200%, after a data-driven delayed complaint. Earlier committed Lost/refusal outcomes cannot be charged a second time by the same dispute, and a late declaration cannot add a second penalty after a confirmed complaint. All accepted operation IDs are durable. Rejected financial operations remain retryable.

Voluntary refusal is distinct from player denial. The player can buy the physical parcel out for 100%, leaving it in the world, or bring it back to the counter the following Morning and choose Return. Both release its number through an explicit warehouse departure reason (BOUGHT_OUT/RETURNED); the terminal retains the latest departed parcel. Return neither refunds nor deletes an already-created complaint. A legitimate complaint about a voluntarily refused order is a separate operation from legal buyout. Future inventory/ownership can consume the visit's BOUGHT_OUT disposition.

Complaint records retain a typed reason (`NOT_DELIVERED` or `DAMAGED`). Delivery stores persistent damaged/opened facts on the visit so delayed damaged-package complaints remain adjudicable after the physical Package is gone. A confirmed damaged complaint currently records a dedicated reputation hook with zero monetary delta; its future monetary penalty is intentionally not hard-coded without a separate game-design value.

Complaint decisions retain the true physical outcome. Successful delivery makes a non-delivery complaint false: the customer-specific record grants a default seven-game-day retaliation reputation window, [resolved_day, resolved_day + 7). A false Taken complaint from a customer defeated by the player before resolution records WAIVED_PLAYER_DEFEAT, keeps the negative fraud reputation reason and charges no money. Other dead claimants have an explicit NO_LIVING_CLAIMANT result. Records remain usable after customer Nodes disappear.

`CustomerVisit.reputation`, typed positive feedback (`APPROVED`) and complaint reason/window fields are future reputation hooks; no global reputation score is implemented. Satisfaction does not replace these reasons. Policy probabilities and timeouts are authored in `DEF_Customer`; rolls are drawn once per stable visit ID and persisted.

## Persistence and regression

R21 must save the complete flow journal, planned-through day, visit policies/rolls/outcomes/disposition/death attribution/settlement flags, complaints and windows, together with the full R10 wallet journal and R06 registry. Live Nodes/AssignedTo are reconstructed from IDs; destroyed scenes are never stored as authority.

`tests/gut/test_customer_flow.gd` covers outcome/financial branches, relationship cleanup, schedule retention, copied records, death attribution and scene-local state. `tests/smoke/customer_flow_smoke.tscn` uses real bodies and counter overlaps through main-scene scheduling, wrong/unregistered/correct/refused delivery, terminal buttons, false Taken, delayed complaints, next-day return and retained late/absent orders. Its fixture seeds the existing scanner registration contract; R06's scanner interaction is covered separately. Existing day/wallet/receiving fixtures disable only customer scheduling to preserve their original focused contracts.

2026-09-27 validation: 27/27 GUT tests (R11 + wallet, 176 assertions) PASS; main-scene customer flow headless smoke PASS after an authorized diagnostic/fix cycle for a route crossing an existing wall. Structure and diff whitespace checks PASS. Optional formatter unavailable. Rendered/visual acceptance was not run.
