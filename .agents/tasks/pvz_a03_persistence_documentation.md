# PVZ-A03 — Актуальный контракт сохранений

Status: **IN_PROGRESS**
Priority: **P2**
Baseline: `dev` / `9e7e889b7466a74e96511dd914835fc77d4b1795`
Dependencies: [PVZ-B01](pvz_b01_configfile_save_storage.md), [PVZ-CAL01](completed/pvz_customers_calendar_fact_ownership.md), [PVZ-A02](completed/pvz_a02_wallet_day_events.md), [PERSIST-DORM01](completed/persistence_baseline_dormant_restore.md)

## Task state

### Goal / scope

Сделать [docs/persistence.md](../../docs/persistence.md) достоверной текущей спецификацией: формат, owners, authority/IDs, safe save, Night capture/retry, passive restore, отказ и защита слота, реальные APIs/tests. В [ARCHITECTURE](../../content/ARCHITECTURE.md#persistence-and-ids) оставить общие роли и ссылку на профильный контракт. Runtime поведение, compatibility и пользовательские файлы не менять.

### Owner decision / changed prerequisite

Первоначальное ТЗ предполагало завершённую миграцию ConfigFile. Последнее указание владельца: «Если не выходит - вернись к старому формату хранения данных». Native ConfigFile не сохранил исходные Float64 значения; эксперимент отменён, B01 **DEFERRED**. Поэтому требования A03 описывать ConfigFile.save/load, unified UTF-8 limit и ConfigFile roundtrip заменены описанием фактически сохранённого PVZH1, существующего payload/whole-file size расхождения и проверяемым roundtrip действующего API. Это не объявляет B01 выполненным и не добавляет новый сериализатор.

### Pinned implementation sources

- CAL01: `9cc33be68ef8fb42ce4ab1965335c6e840722a49` — committed calendar facts / explicit reconciliation.
- A02: `729c345b8df96426916129504e8654d97ca60437` — discrete wallet observer / explicit sync.
- A01: `01af39e1a126e0d1326e474e164efe10d24bfe1b` — native UI composition; owner QA остаётся отдельным.
- B01 fallback: `495cf8f6d9fb0ea3dc0fbc62b5cef32f18971103` — original storage/schema retained.
- PERSIST-DORM01: `e3337db2d7d634ed6ceb5c57d4212f347249b9cb` — preserve already planned dormant placement.
- Все source owners сверены на baseline выше: AutosaveStore, SaveDataCodec, WorldSnapshotService, NightSaveService, S_NightSave, C_Autosave, GameSessionService, GameWorld, main_level, ActorIdentityRules и GameplayResourcePaths. Архивные задачи/provenance не переписываются.

### Acceptance

- [x] Нет противоречащих current schema numbers, legacy path guards и закрытых migration TODO в текущем persistence-повествовании. Сохранён входящий identity anchor.
- [x] Формат, версия, size/error/write contract соответствуют исходникам; известное расхождение лимитов открыто указано. Нет обещаний readback, fsync, power-loss recovery, converter или rollback.
- [x] Описаны фактические группы/clock domains, flush boundary, immutable retry, startup/in-place reconciliation и wallet settlement.
- [x] Есть authority/identity/path таблицы; живые Relationships, body state и derived caches различаются.
- [x] Указаны safe Morning API, preflight, отказ существующего слота и последующий Night; примеры используют отдельные user:// пути.
- [x] Новые ссылки/пути/symbols проверены, исполняемые примеры сверены с опубликованным текстом.
- [ ] Immutable-SHA review собран, triage выполнен, принятые P0/P1/P2 исправлены.

### Validation

- PASS: disposable native GUT examples — 2/2, 14 assertions; `.artifacts/godot_agent/persistence-doc-examples.stdout.log` / `.stderr.log`. Два snippets извлечены непосредственно из финального Markdown; проверены manual Morning save/preflight/restore и rejected slot + реальный Storage step.
- PASS: live Godot AI MCP, editor PID 24672, Godot 4.7.1; ownership: main_menu, no unsaved scenes; `pvz_gdscript_path_diagnostics` для AutosaveStore, S_NightSave, GameSessionService, O_DistrictLifecycle — 4 checked, diagnostics empty, scripts instantiated 0.
- PASS: 30 local links/anchors, 20 source symbols, single version authority; `.artifacts/check_persistence_docs.py` проверяет три изменённых документа и извлекает оба snippets.
- PASS: `validate_persistence_baseline.py`, 7/7 tooling unit tests; incremental architecture smells и scoped diff whitespace check.
- Runtime implementation gates принадлежат зависимостям; полный gameplay/GUT прогон из-за docs-only правок не требуется.
- Visual/gameplay: **NOT_RUN, 0/8**, не требуется для docs-only scope.

### Current / next

Спецификация и архитектурные persistence bullets переписаны; после structure gate — commit и read-only review по точным BASE_SHA/TARGET_SHA. Пока review pending, допустима только независимая работа.

### Review / triage

**NOT_RUN**. Base: `9e7e889b7466a74e96511dd914835fc77d4b1795`; target ещё не создан. Нет принятых findings.

### Completion

DONE только после всего scope, релевантных проверок и review/triage; затем перенести этот файл в completed/ и исправить ссылки. [PVZ-DOC01](pvz_code_documentation_quality.md) использует один текущий persistence-контракт; B01 DEFERRED и A01 OWNER_QA не закрываются этим milestone.

### Owner QA / blockers

Нет runtime/owner QA для docs-only scope. Review ещё не выполнен; это блокирует DONE.
