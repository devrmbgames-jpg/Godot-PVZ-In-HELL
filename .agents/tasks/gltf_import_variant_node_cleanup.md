# QA-GLTF01 — Lifetime временных Node при сохранении import-вариантов

Status: **PLANNED**
Priority: **P2**
Baseline: `dev` / `a0c95f376f294ab8bc1a9daa76097701f43fdc07`

## Task state

### Goal

Проверить и устранить потерю временных Node в gltf_import_split_script._save_variant. Входной import scene принадлежит движку; локальные duplicate/body должны освобождаться на успехе и при отказе pack/save. Контракт файлов, physics transforms и исходный scene не менять. Найдено при [DOC01](pvz_code_documentation_quality.md).

### Current

Source evidence: _save_variant создаёт original.duplicate(), иногда оборачивает новым телом; после PackedScene.pack/ResourceSaver.save не освобождает final_root. Ветка pack error также выходит без cleanup. Caller не получает временный root. Runtime orphan-count reproduction ещё NOT_RUN; выполнить изолированно на минимальном дереве и временном output path, не reimport авторских assets.

### Acceptance

- [ ] Baseline probe показывает рост live orphan Nodes после variant generation.
- [ ] Временное дерево освобождается после pack/save и при ошибке; исходный scene жив и неизменён.
- [ ] Generated PackedScene остаётся загружаемым после cleanup; none/static/rigid покрыты.
- [ ] Focused GUT/native parser/MCP/style и immutable commit/review/triage PASS.

### Validation

NOT_RUN — отдельно зарегистрирован lifecycle scope; production behavior пока не менялось.

### Owner QA / blockers

Visual/gameplay NOT_RUN, budget 0/8. Не выполнять import/bake/migration авторских файлов для reproduction; достаточно отдельного headless процесса и временных test outputs.
