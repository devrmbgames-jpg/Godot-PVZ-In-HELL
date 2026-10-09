# Refactoring v2.04 — identity, persistence и migration baseline

Status: **DONE**

Зависимости: [03_architecture_validation.md](03_architecture_validation.md).

## Goal

До runtime migration закрепить identity/save contract и воспроизводимую baseline. Это Phase 1 contract task; Phase 0 только определяет её scope. По явному указанию владельца 2026-10-07 старые save-файлы не нуждаются в миграции: проект ранний, backward compatibility вне scope.

## Work

- Зафиксировать сохранённые `package/<package_id>`, `npc/<sequence>`, order/operation/history IDs, `Entity.id`, authored scene keys и supported schema.
- Описать target authored stable ID вместо `scene/<relative path>`; без legacy ID mapping или guessed identity. Duplicate/unresolved ID диагностировать до изменения мира.
- Подготовить isolated current-format fixture с ACTIVE/DORMANT physical-root NPC, owned/stored/cargo links, Definitions и record script paths; user autosave не использовать и не перезаписывать. Retained dormant body не означает второй NPC.
- Зафиксировать Night-only prepared-Morning snapshot: finish evening → reset transient sessions → prepare next Morning once → flush owned pending work → capture immutable snapshot → validate/write. Retry не повторяет outcomes/preparation. Не расширять save на arbitrary mid-action/mid-combat checkpoint ради LOD.
- Restore: decode/version/validate all IDs/resources/recipes/endpoints без gameplay effects → fresh world/entity construction/defaults → saved-state overlay → durable links → caches/participation/presentation → ready → simulation. Failed preflight не изменяет live world; unexpected construction failure discards unfinished startup world, без обещания generic transaction rollback.
- Указать path-prefix guards в codec/snapshot и полный перечень save-visible paths для migration map задачи 28.
- Определить change gate: ownership-only шаги сохраняют schema; шаг, меняющий persisted identity/path/shape, поднимает schema version и проверяет отказ несовместимого файла без live mutation. Load migrations и previous-version roundtrip не требуются.
- Старые schema, включая schema 2 после несовместимого изменения, могут быть неподдерживаемыми. Несовместимый пользовательский файл автоматически не удалять и не перезаписывать; current-format fixtures создаются в isolated test slot.
- Для каждой baseline violation указать owning task и removal gate: execution → 26/27, paths/layout → 32/33, core composition/LOD → 49.
- Authored identity: unique local ID scoped by explicit level/world content ID; spawned domain sequence ID allocated once and persisted. Definition/content ID, actor instance key, GECS numeric ecs_id и operation ID — разные namespaces. NpcRecord/C_NpcIdentity refer to one actor ID; reference mirrors не считаются двумя actors. Runtime resolver is derived, no mutable identity alias map. Duplicating imported subscene validates world-scoped uniqueness before registration; ID repair explicit.

## Acceptance

- Identity/current-format contract однозначен до 10–25.
- Baseline fixtures покрывают реально сериализуемые пути, а не только текстовые `res://` references в repository.
- У каждого изменения persisted contract есть schema/version owner и отказ до live mutation при invalid/incompatible/newer data.
- Runtime refactor ещё не начат; fixture/contract preparation не меняет игровой баланс или пользовательский save.

## Validation

Documentation/static baseline inspection. При создании fixtures — профильная проверка codec roundtrip на isolated данных. Ни gameplay migration, ни широкая suite в этой задаче не требуются.

## Current — 2026-10-08

В [docs/persistence.md](../../docs/persistence.md#refactoring-v2-identity-contract) закреплены current schema-2 namespaces и target scoped authored identity, Night prepared-Morning quiescence/immutable retry, restore defaults→overlay→links→cache→ready, version/file-preservation policy и explicit baseline debt owners/removal gates. Current manual safe-Morning slot не расширен; target не обещает произвольный mid-action checkpoint или generic rollback.

Созданы [save-visible inventory](../../tests/fixtures/refactoring_v2/save_visible_paths.json) (31 Component с точными fields, 14 record scripts, 46 реально captured paths) и [native Variant snapshot](../../tests/fixtures/refactoring_v2/current_snapshot.variant), полученный настоящим WorldSnapshotService.capture (current-format fixture обновляется owning migration; schema 3 с задачи 19). Fixture содержит population aggregate с 12 реальными physical-root NPC, ACTIVE/DORMANT equivalents, injured absent actor, owned inventory/order key, stored/cargo links, package/history key, financial operation/receipt/delivery, memory и receiving selected-scene path. Definitions включают inline `.tres::Books` subresource; static tool проверяет файл, engine проверяет разрешение самого subresource.

GUT suite загружает committed snapshot, пишет только `user://gut_refactoring_v2_phase1.pvzh`, проверяет binary/store/restore roundtrip, single retained actor и links; отдельный codec test проходит все 31/14 type paths. Duplicate/unresolved ID и unsupported schema 1/newer отклоняются без live mutation; isolated incompatible file остаётся byte-identical. User autosave не читается/не меняется. Default-record coverage — codec shape/path evidence, не обещание всех gameplay combinations.

Static `utils/validate_persistence_baseline.py` сверяет closed codec/fields/schema и реальный path inventory. Пять tool tests проверяют schema/field/path drift, move и inline subresource handling. Explicit golden update flag не используется обычным прогоном.

Baseline findings: generic service debt остаётся в explicit baseline 03 с gate26/27; path/guard/raw receiving-choice migration —25/28–33; procedural bootstrap/participation —41/42/45/49. CharacterBody cart без persisted capability пропускается current capture: fixture явно задаёт C_PersistentIdentity, normal gameplay endpoint policy назначена21/25. Night currently recaptures on write retry; immutable retained snapshot/drain остаются25. Runtime миграция и баланс не изменены.

Read-only review выявил wording gap: incompatible file preservation должно запрещать и последующий Night overwrite, не только startup mutation. Запрет закреплён в docs и прямо в owning task25. Текущий runtime не имеет rejected-slot protection; fixture доказывает только immediate rejection preservation. Это явно перечисленный implementation debt25, не заявленная здесь runtime гарантия.

## Validation result

- `python -B utils/validate_persistence_baseline.py`: PASS, 31 Component/14 record/46 captured paths.
- `python -B -m unittest discover -s tests/tools -p test_validate_persistence_baseline.py`: PASS, 5 tests.
- Godot 4.7.1 / GUT 9.7.1: `--headless --path . --script addons/gut/gut_cmdln.gd -gtest=res://tests/gut/test_refactoring_v2_persistence_baseline.gd -gexit`: PASS, 3 tests / 253 assertions; normal read-only fixture run, new script parsed without script errors/reload warnings. Финальные assertions также проверяют retained same body и cargo integrator/cache; fixture не замораживает активный cargo вопреки его physical contract. Windows certificate-store message is an environment diagnostic, not a test assertion. Live MCP diagnostics attempt был недоступен (PLUGIN_DISCONNECTED); parser proof получен headless GUT, MCP PASS не заявляется.
- `python -B -m unittest discover -s tests/tools -p 'test_validate*.py'`: PASS, 50 tests.
- Architecture transition, full project structure, roadmap links/dependencies и `git diff --check` для owned scope: PASS. Unrelated `.codex/config.toml` edits сохранены и не входят в commit/check scope.
- Task03 restored truck smoke ранее PASS; повторный broad gameplay run не требуется после fixture/contract changes.

Rendered/subjective QA не запускались; для Phase 1 contract/fixture acceptance owner QA не требуется. Runtime migration must still prove the target gates in the owning tasks; эта Phase 1 не объявляет их реализованными.

## Phase 1 acceptance / Next

01–04 DONE: canonical role/ownership contract, audited execution/timing rules, guarded legacy baseline, repaired full structure и isolated identity/persistence evidence завершены. Phase 1 acceptance gate достигнут; остановиться перед runtime migration.

Следующий milestone: Phase 2A, [10_service_inventory.md](10_service_inventory.md), затем40 по roadmap dependency order. Не начинать 10 в этой Phase 1 сессии.
