# Refactoring v2.32 — shared core и удаление horizontal gameplay roots

Status: **DONE**

Зависимости: [31_domain_world_economy_packages.md](31_domain_world_economy_packages.md); domain migrations 29–30 завершены по chain, [33_domain_dependency_validation.md](33_domain_dependency_validation.md) уже включён.

## Goal

Оставить в `content/shared/` только настоящий cross-domain infrastructure и убрать legacy horizontal gameplay layout.

## Work

- классифицировать всё оставшееся в старых `components/services/systems/... `;
- перенести genuine shared contracts/rules/authoring infrastructure в `content/shared/<role>/`;
- вернуть domain-specific leftovers владельцу;
- удалить пустые legacy gameplay roots;
- не переносить UI Control glue в ECS/shared без необходимости.

## Acceptance

`python utils/validate_domain_structure.py --strict` PASS.
Legacy horizontal gameplay roots отсутствуют.

Strict dependency rerun 33 PASS с пустой migration baseline. Shared→domain internal imports отсутствуют. Old path-prefix guards, tests/tooling roots и save paths обновлены; несовместимый persisted формат versioned и old saves отклоняются, не конвертируются.
Новый разработчик определяет owner файла по пути без глобального поиска по role root.

## Validation

Strict domain validator + project structure + parser all moved scripts.

## Result

Complete task-32 map: **46/46 entries**, including 41 Shared/global path moves, two already-canonical identity-contract files and three original dialogue import-sidecar repairs. All native script/resource UID paths and incoming code/resource/test/tooling references updated. All **16 legacy horizontal roots physically absent**; current PROJECT_INDEX routes to domain/shared ownership.

C_ActorIdentityReference projects the existing Package/NPC/persistent Component ID fields through read-only methods. No identity mirror, alias map, duplicate authority or allocation was added. ActorIdentityRules preserves snapshot/diagnostic key priorities; BoundaryTrace identity resolver and all its callers migrated. Three final Shared-to-domain imports and all migration exemptions/decomposition entries removed. Strict layout and dependency enforcement are now part of ordinary project structure validation.

The original tracked dialogue .import sidecars had been left behind while newly imported canonical assets acquired different UIDs. Preserved the three original native UIDs at canonical domain paths, removed the superseded old sidecars, and added import UID/asset/source_file coverage to the migration validator. LimboAI user task directories now point to both actual domain task roots.

Current save schema **8**, actual native golden and manifest reflect final Shared paths. Horizontal Definition-prefix support removed. Incompatible saves reject without migration, deletion or automatic overwrite.

The fresh-process parser validates compiled Script resources and isolates GUT fixtures in project-aware child parser processes. Ordinary and abstract syntax failures reject, valid abstract scripts pass; no diagnostics are waived. This avoids retaining unmanaged GUI/script graphs when unrelated GUT fixtures are combined outside the actual GUT lifetime owner.

## Validation

Executed 2026-10-09:

- Strict domain structure, strict dependency with **empty baseline**, complete migration map, project structure, strict architecture, preflight and persistence validators: PASS.
- Domain tooling fixtures **33/33**, including import-sidecar missing coverage/wrong owner/source_file/native UID and completed move regressions; persistence fixtures **5/5**.
- Godot final parser: **31 files PASS**, zero errors/warnings (`refactoring_v2_32_final_parser.log`); final readability touch **3 files PASS**.
- Parser negative ordinary/abstract syntax and isolated GUT fixture: expected **FAIL / exit 1**; valid abstract: **PASS / exit 0**. Exact temporary invalid GUT fixture removed after validation.
- Final GUT **614/614 tests, 5330 assertions across 37 scripts**, zero runtime diagnostics (`refactoring_v2_32_final_gut.log`). Identity boundary also independently passed **72/72, 892 assertions**.
- Actual native schema-8 golden capture/roundtrip/rejection **3/3, 274 assertions**; synced from actual codec/native save.
- Actual headless main write/fresh restore: **PASS** (`vertical_slice-20261009-071151088.log`).
- Actual hazards gameplay assertions and shutdown: **PASS** (`hazards-20261009-071200217.log`).

No rendered gameplay or subjective visual QA. No old-save migration. Unrelated AGENTS.md/addons/gecs edits preserved.

## Current / Next

**DONE — PASS.** Phase 2B complete; strict task-33 rerun accepted without migration baseline. Continue Phase 2C with [47 — Game Time and deterministic randomness](47_game_time_randomness.md), then README dependency order through PASS 49. Do not begin Phase 3.
