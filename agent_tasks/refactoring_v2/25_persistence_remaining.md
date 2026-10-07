# Refactoring v2.25 — Persistence и remaining services

Status: **PLANNED**

Зависимости: [24_economy_inventory_commerce.md](24_economy_inventory_commerce.md); задачи 10–23 завершены по последовательному execution chain.

## Goal

Закрыть весь service inventory: отдельно проверить persistence/input/UI/debug и все файлы, не попавшие в доменные задачи.

## Persistence

Codec/snapshot/store/validation helpers обычно остаются вне ECS scheduling. Old-schema converters вне scope по решению владельца.
Отделить serialization от gameplay authority.
Не менять save schema только ради архитектурной чистоты без отдельной необходимости.

This milestone implements the explicit stable authored actor identity specified in 04, before path moves 28–32. Assign world/level-scoped local instance IDs to every persistent placed Entity; generated domain IDs remain persisted sequences. Remove scene/<relative path> fallback and NodePath-based restore matching with all callers/scenes/fixtures; diagnostic scene paths are not identity. Bump incompatible schema, reject old saves; test that renaming/reparenting an authored node retains identity and links. No legacy-key alias. Phase 1.04 defines the contract; it does not perform this runtime migration.

Complete safe snapshot/reconstruction contract из 04: Night prepared-Morning quiescence, no pending structural/outcome work at capture, no repeated preparation on write retry, immutable snapshot before I/O. Validation includes all prefab/recipe/ID/link checks before live replacement; new-template startup suppresses gameplay effects until restore/fixup. Missing required endpoint rejects; explicitly optional endpoint may be dropped with a reason, never guessed. Invalid save leaves prior valid state/file intact; unexpected startup construction failure abandons incomplete world rather than simulating partial restore. No old-save converters or aliases.

Protect an incompatible rejected user slot from later automatic writes as well as immediate startup mutation. Rejected startup followed by Night must preserve the file byte-for-byte until explicit reset/replacement or another slot is selected. Current NightSaveService has no rejected-slot protection; 04 documents this baseline debt, not completed safety.

Persistence owns storage/codec/composition of snapshot adapters; domains own state and expose schema contracts. Domain→Persistence imports/autosave calls migrate to global composition bindings, keeping the import graph acyclic. UI/BT/navigation/perception/reservation queues are reconstructed/reset under Night policy, not serialized as live Objects. Actual current-format roundtrip includes dormant registered bodies and per-field NPC aggregate metadata.

## Remaining services

Для каждого ещё не закрытого inventory item выполнить назначенный KEEP/MOVE/SPLIT/RENAME/DELETE.
Проверить naming: класс с ролью Geometry/Rules/Solver/Presentation не обязан называться Service.

## Acceptance

100% строк service inventory имеют финальный статус **DONE/KEPT_WITH_REASON**.
Нет «временно оставленных» hidden schedulers.

## Validation

Persistence/save regression tests для затронутых файлов; parser; structural validator.
