# Current Work

Status: active
Task: Developer Console Testing
Source: agent_tasks/developer_console_testing.md
Current milestone: Stage 2 complete

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
- content/scenes/main_level.tscn

Validation:
- static inspection only; Godot/GUT not run.

Next:
- Stage 3: implement Package spawn/remove/register through domain-safe debug adapters.
