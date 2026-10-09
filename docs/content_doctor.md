# Content Doctor

Content Doctor validates authored content without starting a level. It loads native resources,
instantiates scenes outside the SceneTree, and reuses the Entity compiler, placed identity,
Smart Object and refusal quest providers. It does not register Entities, install Components,
advance behavior trees, evaluate dialogue expressions or call context methods.

Run the complete structural and content acceptance gate from the repository root:

```powershell
python -B utils/validate_project_structure.py --content-doctor
```

For a content-only scan:

```powershell
python -B utils/validate_content_doctor.py
```

Both commands use the pinned console executable in `.bin`. An explicit executable can be
supplied with `--godot <path>`. Missing Godot returns `NOT_RUN` / exit 2. Normal validation
returns exit 0 only when the native scan completes, its report is valid, and no unexpected
engine diagnostics occurred. Errors and unresolved review gates return exit 1.

The latest report is `.artifacts/content_doctor.json`; native console evidence is
`tests/artifacts/content_doctor.log`. These paths are overwritten on each run. The driver
removes the preceding JSON before launching Godot so a failed process cannot reuse stale
success. The Godot CLI can also write a caller-selected report:

```powershell
.bin/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script utils/content_doctor.gd -- .artifacts/content_doctor.json
```

The scan enumerates `.tres`, `.res`, `.tscn`, `.scn` and `.dialogue` under `content/`, then
includes native PackedScene references and exported resource paths. Dependency preflight
rejects missing files and native cycles before loading recursive assets. Diagnostics contain
`severity`, `code`, `source`, `field` and `message`; the field also preserves Entity instance
and Trait provider context.

Scene compilation checks Template/Traits, Component providers, initial bindings, native root
and node capabilities, and duplicate placed IDs. Unused Templates still use the compiler's
shared declaration provider. District NPCs are compiled against each actual district roster
Profile selecting that prefab; addresses use actual authored HOME definitions. A prefab with
no declared district producer inputs has an explicit review gate. Validation does not invent
runtime identity or silently accept an unverified factory contract.

Resource checks include native exported ranges, finite authored numbers, schedule locations
and weekdays, NPC Trait compatibility, district place/route keys, attack ranges and durations,
concrete action executors and existing quest issuer/Definition rules. Native NPC locomotion
and compiled attack animation names must exist in the corresponding AnimationPlayer.

Imported Dialogue Manager 4.1 resources are inspected directly. Required entry cues come from
the existing street/service integrations and referenced Customer Definitions; semantic response
tags use the current gameplay contract. Context methods are reflected from the declared Script
and its script bases, including required/default parameter counts. Static transitions, response,
concurrent, random and case links are checked. Unreferenced dialogue integrations, dynamic jumps
and unsupported expressions produce `REVIEW_REQUIRED`; expressions are never executed to
discover their result. New context integrations must declare their validation contract before
the full content gate can pass.

Only the owner's specified Godot 4.7.1 shutdown retention category can be recorded as
`KNOWN_ENGINE_LIMITATION / DEFERRED`. Console logs remain available. Errors before the native
completion marker, unknown warnings, and retained Nodes/plain Objects remain failures.

Focused provider and broken-content coverage lives in `tests/gut/test_content_doctor.gd`;
acceptance-driver diagnostic classification is covered by `tests/test_content_doctor_driver.py`.
The first integrated project scan checked 90 scenes and three imported dialogues in about
12 seconds on the development machine. These checks provide structural evidence; they do not
replace gameplay or visual QA.
