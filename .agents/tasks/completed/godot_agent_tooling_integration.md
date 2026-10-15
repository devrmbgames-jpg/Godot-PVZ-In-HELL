# Godot Agent Tooling — editor ownership and independent CLI validation
Status: **DONE** — принято владельцем 2026-10-15.

## Task state

### Goal

Avoid blocking the active Godot 4.7.1 editor through external `.tscn` /
`project.godot` writes, while keeping native headless validation independent
of MCP. Authorize bounded recovery of a confirmed project settings modal,
and project-owned Godot AI MCP extensions.

## Implemented

- `AGENTS.md` routes live scene changes through MCP; no unsafe external-file
  fallback over open editor-owned content.
- `.agents/skills/godot-scene-authoring/SKILL.md` and
  `.agents/skills/godot-ai-mcp/SKILL.md`: native live scene/save, unsaved-state
  guard, safe offline migration, recovery, custom-tool extension policy.
- `.agents/skills/validation-workflow/SKILL.md` requires actual engine checks
  even when MCP is not available.
- `utils/godot_agent.ps1`: pinned 4.7.1 runner for parser, focused GUT,
  import and CLI `SceneTree`/MainLoop scripts; import/mutation refuses an
  active project editor. VS Code tasks delegate to the same runner.
- `.vscode/start-godot.ps1` no longer overwrites Codex's `CODEX_HOME`.
- `.vscode/stop-blocked-godot.ps1`: manually/agent-invoked only after
  confirmed `project.godot` modal, exact PID + `--editor --path` verification,
  evidence logging, optional restart, no blanket process kills.
- Companion `addons/pvz_ai_tools/` registers
  `custom_pvz_editor_ownership` with open/unsaved scene report; scoped,
  read-only, synchronous; does not mutate GECS or gameplay.
- `docs/godot_agent_tooling.md` contains commands and acceptance scenarios.
  Этот tooling checkpoint не изменял vendored Godot AI / GECS или `project.godot`.
  Позднейший bounded translation-source companion и native settings cleanup принадлежат
  [задаче инструментов района](district_bin_cleanup.md), включая закрытый RV-001.

### Validation

- PASS: native PowerShell parser and four executable runner contracts (selection,
  vendored-addon exclusion, companion inclusion, both editor flags, unverifiable CIM refusal).
- PASS: actual Godot parser for companion ownership tool and GUT; ownership GUT 3/12.
- PASS: live MCP ownership for verified project editor PID 19908; no unsaved scenes.
- PASS: Import refuses the active editor launched with `-e`; no process terminated.
- PASS: structure after restoring task-state headings and replacing nonexistent GUT paths.
- PASS: incremental formatter and architecture-change gates.
- PASS: scoped independent review, source `cade343ebe252f22623ab0d99ec805bb2e84188f`,
  follow-up `a32a80e3b01e7c2eeade98a41fe2612d54ffbeba` from baseline below;
  no material findings. Reviewer VALIDATION NOT_RUN; Main's actual checks above.
- PASS: complete tooling 134/134; native companion parameter/overlap GUT2/5;
  live native Inspector signal check9/9, original Inspector restored, no new editor errors.
- Logs: `.artifacts/godot_agent/`; original-project native editor regression is blocked
  by the live LimboAI DLL. Its failed process alone was stopped; owner editor preserved.

### Current

**Завершено: владелец принял результат 2026-10-15.** Новые замечания и запланированные доработки сохраняют собственный незавершённый статус.

Техническая контрольная точка до ручной приёмки; прежние пометки ожидания OWNER_QA ниже закрыты решением владельца:

Baseline: `c8b84b801d674a293d4519e266e2f656883617dd`, `dev`.
The baseline runner had a truncated regex and duplicated tail (10 PowerShell parse errors).
Restored one executable body and recognized `-e` alongside `--editor` for offline guards.
New bounded companion signal verification checks the Direct Traits Inspector in the live
editor without saving scenes/settings or disturbing authored content; nine assertions PASS.

Local acceptance is complete at reviewed source
`14b2934de1068ca501a29b0150a90096dccc40d2`:

- PASS: live MCP in Godot 4.7.1, verified project editor PID 15008.
  Created `res://tests/artifacts/editor_ownership_acceptance.tscn` through
  native scene operations; added a Node3D and instantiated the authored
  `npc_service_routes.tscn` subscene. Ownership changed from clean/0 to
  unsaved/1 and back to clean/0 after native save. Saved clean scene reopened
  from disk with both children intact; original main menu restored.
- PASS: guarded recovery `-EditorPid 15008 -WhatIf` did not terminate the
  editor, verified afterward. Supplying PowerShell PID 14688 refused with
  `not a Godot executable`. No actual modal recovery or termination claimed.
- PASS: independent final scoped source review from baseline above to
  `14b2934de1068ca501a29b0150a90096dccc40d2`, no material findings;
  ARCHITECTURE/STYLE PASS, reviewer VALIDATION NOT_RUN. Review took 48 seconds;
  serial comparison/token telemetry NOT_MEASURED.
- PASS: no new editor log entries after cursor 4 during live acceptance.
  Existing cyclic-authoring fixture diagnostics are not a clean-log claim.

Next: owner editor/modal and subjective acceptance in
[the tooling QA checklist](../../../.qa/tasks/godot_agent_tooling.md).

### Owner QA / blockers

Принято владельцем 2026-10-15 по сообщению «Закрой все задачи где OWNER_QA». Ранее реализованный объём закрыт общей приёмкой; новые замечания остаются отдельными задачами. Поштучный прогон всех сценариев и новая визуальная QA агентом не заявляются.

Shutdown-only retention остаётся KNOWN_ENGINE_LIMITATION / DEFERRED; прежние технические evidence сохранены.
