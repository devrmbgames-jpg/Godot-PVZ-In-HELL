# Current Work

Status: active
Task: Developer Console Testing
Source: agent_tasks/developer_console_testing.md
Current milestone: Stage 4 complete

Invariants:
- addons/console stays generic; project commands live under content/debug/.
- console callbacks do not become gameplay authority.
- Actual Customer outcome and Terminal declaration remain separate.
- debug commands are production-disabled by default.

Changed paths:
- content/debug/debug_target.gd
- content/debug/debug_target_resolver.gd
- content/debug/developer_console_output.gd
- content/debug/developer_console_commands.gd
- content/debug/developer_console_diagnostics.gd
- content/debug/debug_service_result.gd
- content/debug/debug_package_service.gd
- content/debug/debug_customer_service.gd
- content/contracts/customers/customer_visit.gd
- content/contracts/customers/customer_complaint.gd
- content/services/customers/customer_outcome_service.gd
- content/services/packages/package_registration_service.gd
- content/scenes/main_level.tscn

Validation:
- static inspection only; Godot/GUT not run.

Next:
- Stage 5: implement journaled debug wallet credit/debit/manual penalty and compensating penalty reversal.
