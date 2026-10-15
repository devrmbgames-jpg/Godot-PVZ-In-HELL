# QA-GLTF01 — Lifetime временных Node при сохранении import-вариантов

Status: **IN_PROGRESS**
Priority: **P2**
Baseline: `dev` / `a0b3fc8c75a08e16b1bc935b04c926c5c7b4f9e3`

## Task state

### Goal

Проверить и устранить потерю временных Node в gltf_import_split_script._save_variant. Входной import scene принадлежит движку; локальные duplicate/body должны освобождаться на успехе и при отказе pack/save. Контракт файлов, physics transforms и исходный scene не менять. Найдено при [DOC01](pvz_code_documentation_quality.md).

### Current

Подтверждён owned Node leak: isolated headless editor 4.7.1/Jolt, прогрев трёх вариантов и 50 циклов none/static/rigid (150 saves): baseline orphan count 326→826 (+500). `_save_variant` теперь освобождает принадлежащий ему final_root сразу после pack, до проверки pack error и любого save. Входной scene не освобождается и не меняется; PackedScene удерживает сериализованное состояние. Pack-error branch проверен по control flow, принудительный отказ pack не инъецировался.

Base `a0b3fc8c75a08e16b1bc935b04c926c5c7b4f9e3`; target после commit. Review **REVIEW_PENDING**, не DONE. Реальный GUT runtime не может создавать EditorScenePostImport (editor-only); вместо изменения native контракта добавлен focused editor validator `tests/validators/gltf_import_variant_lifetime.gd`. Он запускается в отдельном scratch project, использует точные копии двух scripts; исходный проект не импортируется и его открытые ресурсы не записываются.

### Acceptance

- [x] Baseline probe показывает рост live orphan Nodes после variant generation.
- [x] Временное дерево освобождается после pack и до любой ветки отказа; исходный scene жив и неизменён.
- [x] Generated PackedScene остаётся загружаемым после cleanup; none/static/rigid покрыты.
- [ ] Focused native validator/parser/MCP/style и immutable commit/review/triage завершены.

### Validation

- **FAIL baseline**: `.artifacts/qa_gltf_native/.artifacts/godot_agent/offlinescript-20261015-221129297.stdout.log` / `.stderr.log`; 18 checks, 1 failure (orphan growth +500), process exit1. Сохранённые variants и source fidelity уже проходили.
- **PASS lifetime assertions** final Jolt: `offlinescript-20261015-221344483`, 18/18, process exit0. Orphans316→316, Resource counter23→23; Node monitor21479→21479. Object delta+150 совпал с print-only control+150 (editor output history). Static bytes сняты в обоих gates; RSS/Private Bytes **NOT_MEASURED**, общий zero-allocation claim не делается.
- **FAIL wrapper / KNOWN_ENGINE_LIMITATION / DEFERRED**: OfflineScript маркирует process exit0 как FAIL из-за shutdown-only editor RID warnings (viewport, texture, scenario, shaped text/font). Их stderr/stdout сохранены. Рост orphan Nodes устранён; Jolt body/shape RID retention из baseline больше не появляется. Runner/engine warnings не подавлялись.
- **PASS** native parser2/0 (`parsechanged-20261015-221237762`), final validator1/0 (`parsefiles-20261015-221343102`), оба stderr пустые; MCP2 checked/empty/no instances и final validator recheck1 PASS.
- **PASS** formatter2, agent validator1 applicable path, strict architecture0 findings, structure и scoped whitespace. MCP global editor log не объявляется чистым: после старта есть отдельные NPC class-resolution rows и намеренно cyclic fixtures; changed-path diagnostics чистые.

### Reproduction entry

Scratch project `.artifacts/qa_gltf_native/project.godot`: `config_version=5`, `application/config/name="PVZ GLTF variant lifetime probe"`, `physics/3d/physics_engine="Jolt Physics"`; headless rendering. Скопировать production importer в scratch `utils/gltf_import_split_script.gd`, validator в scratch `probe.gd`, сверить SHA256 копий. Команда из корня проекта:

```powershell
& utils/godot_agent.ps1 -Action OfflineScript `
  -ProjectRoot "$PWD/.artifacts/qa_gltf_native" `
  -GodotPath "$PWD/.bin/Godot_v4.7.1-stable_win64_console.exe" `
  -ScriptPath res://probe.gd
```

Это отдельный project root без live editor; основной MCP editor может оставаться открытым. Baseline importer брать побайтово через `git show a0b3fc8c75a08e16b1bc935b04c926c5c7b4f9e3:utils/gltf_import_split_script.gd`. Final importer SHA256 `4AF20CFBE5B4F2B31C79678736940F3A84A3A22F85639E4E38C67C454ECF0780`; validator SHA256 `3147B7CCB58650844C9D3EF9CE8873D9AAB1868E09FAFC2BA6B87B0F848FC400`. Копии совпали; outputs только в уникальном user://-каталоге и удаляются после проверки.

### Owner QA / blockers

Visual/gameplay NOT_RUN, budget 0/8. Не выполнять import/bake/migration авторских файлов для reproduction; достаточно отдельного headless процесса и временных test outputs.
