# Local Godot validation runner

`godot_agent.ps1` uses pinned Godot 4.7.1 and preserves its existing actions:
`Version`, `ParseChanged`, `ParseFiles`, `GUT`, `Import`, `OfflineScript`.
For example:

```powershell
& utils/godot_agent.ps1 -Action GUT -TestPath res://tests/gut/test_npc_stalking_episode_rules.gd
& utils/godot_agent.ps1 -Action ParseFiles -Paths res://content/domains/customers/observers/o_customer_npc_interruption.gd -TimeoutSeconds 60
```

`-TimeoutSeconds` is optional and Windows-only; zero retains the previous unlimited wait.
A timeout terminates the owned wrapper/process tree, waits for captured child handles
and fails the check. It does not target other editor/test processes. Offline
scene/import operations still refuse to run beside this project's GUI editor.

Every executed validation writes unchanged native `.stdout.log` and `.stderr.log`
files plus an additive `.result.json` under `.artifacts/godot_agent/`. Version and
ParseChanged's `NO_CHANGES` shortcut keep their previous behavior. Existing PASS/FAIL
console prefixes and exit codes remain compatible; UNKNOWN returns exit 1.

The result manifest has `schema: 1`, `action`, `engine_version`, `native_exit_code`,
raw log paths and `result` containing:

| Field | Meaning |
| --- | --- |
| FunctionalStatus | PASS, FAIL or UNKNOWN for the executed check. |
| DiagnosticStatus | CLEAN, FAIL, UNKNOWN or KNOWN_ENGINE_LIMITATION. |
| DiagnosticDisposition | DEFERRED for the approved engine category; otherwise DiagnosticStatus. |
| CompletionVerified | Exact parser marker or one complete passing GUT total/marker. |
| TimedOut | The native process exceeded the requested limit. |
| Diagnostics / UnknownDiagnostics / KnownShutdownDiagnostics | Classified messages; raw logs remain authoritative. |

The automatic shutdown exception is deliberately narrow: the exact native resource
retention summary followed immediately by `clear (core/io/resource.cpp:<line>)`,
with native exit 0 and verified completion. Missing/wrong shutdown callsite, missing
completion or mixed errors cannot PASS. ObjectDB summaries do not identify retained
classes, so they remain UNKNOWN. Unverified RID, StringName and PagedAllocator output
also remains FAIL/UNKNOWN. Do not broaden classification by matching those words.
Nonzero final GUT `Orphans` totals fail; interim per-test orphan reports remain UNKNOWN
even if passing tests have a success marker. Neither is the deferred Resource category.
The owner's broader engine policy can still support a separately evidenced manual
classification; the runner does not investigate or alter ownership to remove warnings.

The existing count/path-matched ConfigFile expected-negative contract remains local
to successful GUT execution. It cannot suppress other script/assert/parser errors.
GUT requires a nonempty complete suite; Import/OfflineScript retain exit-based clean
success and cannot use the shutdown exception without a verified completion marker.

Native GUT already accepts comma-separated `-gtest` paths. The measured pure pair
`test_npc_stalking_episode_rules.gd,test_customer_parcel_reaction_rules.gd` preserves
19 individual test results and 187 assertions in either order. This is not proof of
isolation for World/save/physics fixtures; keep those in separate processes until
their own isolation is demonstrated. The runner's single-file GUT interface remains.
