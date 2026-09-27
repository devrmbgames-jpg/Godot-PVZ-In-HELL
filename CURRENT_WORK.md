# Current Work

Status: active — R11 customers / delivery / disputes
Task: `agent_tasks/roadmap_11_customer_flow_and_delivery.md`

- Actual outcome and terminal declaration remain separate; false TAKEN is legal.
- Live parcel assignment uses R_AssignedTo; persistent records use stable IDs only.
- Customer movement remains Godot body-owned; no storage teleport for delivery.
- Preserve pre-existing debris scene/addon edits and R09 UID files.

Changed: customer contracts, definitions, C_CustomerFlow/C_CustomerAgent, R_AssignedTo, CustomerOutcomeService.
Validation: structure PASS; headless import without script parse/compile errors; GUT/smoke not run yet.
Next: add focused customer GUT and headless physical-counter walkthrough; run final checks once.
