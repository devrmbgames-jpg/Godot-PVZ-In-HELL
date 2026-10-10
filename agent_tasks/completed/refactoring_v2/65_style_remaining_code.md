# Refactoring v2.65 — Code Style: remaining project-owned GDScript

Status: **DONE**

Зависимости: 64_style_gameplay_services.md.

## Goal

Закрыть всю project-owned GDScript базу, не оставив второстепенные скрипты вне общего стандарта.

## Scope

Проверить и привести к стилю:
- оставшиеся `content/domains/*/entities/**` и `content/shared/**`;
- content/ui/**;
- оставшиеся `content/domains/*/ai/**`;
- scripts рядом со сценами/resources;
- utils/**;
- tests/** — с разумным исключением для test readability;
- project tooling вне addons/.

## Constraints

Tests тоже должны быть читаемы, но не превращать компактные table-driven fixtures в церемониальный production-код.
Generated/imported files не форматировать вручную.
Third-party addons/ исключены.

Scope задаётся дополнением manifest 61–64 до полного project-owned `.gd` set; global UI/scene/debug glue сохраняет обычную Godot ownership.

## Acceptance

Full-project style scan не находит project-owned GDScript, не относящийся ни к одной завершённой style task.
Style gate + parser PASS.

## Validation

Full project-owned style check, parser, structure.

## Current checkpoint

Implementation and independent immutable review complete. Manifest task65 owns330
scripts; all980 project-owned scripts are assigned exactly once across tasks61–65.
Formatting, typed local expressions and explicit conditional branches preserve guards,
ordering, paths, signals and authored state. Private fixture probes use native Object
reflection; static-class probes cast to Script. PackageLifecycleEvent.Kind constants
are uppercase with unchanged numeric values0–3 and all mandatory callers migrated.
Repeated load paths remain String constants, preserving load timing/cache identity.
No third-party addon, authored scene/resource or project settings changes are staged.

The independent [native diagnostics defect](native_diagnostics_self_compile.md) is
repaired with focused regression tests; its review is part of this checkpoint.

## Validation evidence

- Full formatter/linter/role naming PASS:980 files, no rule suppression.
- Native MCP compiler PASS:330/330, no gameplay instances created; editor remains alive.
- Focused CLI ParseFiles PASS: `parsefiles-20261010-101902583` logs.
- General ParseChanged wrapper reports FAIL7 for shutdown-retention-only fixture logs,
  `parsechanged-20261010-094539421`; each actual compiler reports PASS before shutdown.
  Classification: KNOWN_ENGINE_LIMITATION / DEFERRED by existing owner policy.
- Initial profile run:44 loaded suites,717 passing tests,6096 assertions; three other
  suites failed to load due static reflection syntax. Repaired follow-up:4/4 suites,
  56/56 tests,534 assertions PASS, stderr empty (`repairs65_gut` logs).
- Headless customer_inspection smoke PASS (`customer_inspection-20261010-201713611`).
- Strict architecture/domain/dependency and project structure PASS; tooling141 tests PASS.
- Final focused GUT:2/2 suites,19/19 tests,97 assertions PASS, stderr empty (`last65_gut`).
- Incremental agent guard FAIL2/REVIEW: developer_console_commands crosses its size
  threshold through formatting, with the same console-command dispatch responsibility;
  gltf_import_split_script preserves the existing offline @tool import/save operation.
  No runtime scaffolding is introduced. Independent review confirms both conclusions;
  raw automated result remains FAIL, not PASS. RV-001 and RV-002: REJECTED with this
  source evidence, because neither candidate violates the architecture contract.
- Owner accepted current Inspector/Direct Traits and Gameplay Debugger2026-10-10.
  No rendered/visual QA by agent is claimed.

## Independent review

Base `3f0499aab47bf2ad0a93e69b29ec2b40ac26db0a` to source
`287933e0c19c141ade715503063844fb7606a75f`: ARCHITECTURE PASS, STYLE PASS,
no material findings; reviewer VALIDATION NOT_RUN. Main ran the checks above.
The self-compilation defect is reviewed/closed with the same checkpoint.
