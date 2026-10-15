# QA-SAVE01 — Полный preflight перед записью debug-слота

Status: **DONE**
Priority: **P2**
Baseline: `dev` / `7b38cc4b1d0914c34eb0d23a1c03c372418e87ba`

## Task state

### Goal

DebugGameplayService.save_slot(writing=true) должен отвергать snapshot, который проходит structural valid, но не восстанавливается из текущих prefab/Traits. До полного preflight нельзя заменять существующий изолированный debug-файл. Scope: один write gate в `content/debug/debug_gameplay_service.gd` и regression в `tests/gut/test_console_gameplay.gd`. Формат PVZH1/schema19, обычные слоты и load path не меняются.

Дефект найден при [DOC01](pvz_code_documentation_quality.md); это отдельное исправление поведения, не comment-only batch. Архитектурный owner остаётся WorldSnapshotService.can_restore; debug adapter не вводит собственную схему/вторую проверку capabilities.

### Reproduction

На baseline запись использует только WorldSnapshotService.valid. Реальный headless regression сначала пишет исправный уникальный debug-слот, затем моделирует scene-role drift: inventory item с R_OwnedBy указывает на package prefab без сохранённой C_Package identity. `valid(snapshot)` возвращает true, `can_restore(snapshot)` — false; прежний adapter всё равно возвращает success и заменяет файл.

Baseline GUT: `utils/godot_agent.ps1 -Action GUT -TestPath res://tests/gut/test_console_gameplay.gd` — **FAIL**, 8/9 tests, 82/84 asserts. Падают только rejection/byte-preservation assertions нового regression; структурный и полный gates ведут себя ожидаемо. Logs `.artifacts/godot_agent/gut-20261015-183701495.stdout.log` / `.stderr.log`; stderr пустой.

### Acceptance

- [x] Воспроизводимый valid=true/can_restore=false случай показывает ошибочную замену исправного слота.
- [x] Write path вызывает can_restore до создания каталога/записи; refusal сохраняет байты и live World.
- [x] Focused console GUT, native parser/MCP и style/static checks проходят; прежний valid roundtrip работает.
- [x] Отдельный checkpoint с full BASE_SHA/TARGET_SHA, read-only review и завершённым triage.

### Current

Единственный write gate заменён на can_restore; loader/формат не изменены. Test проверяет refusal, byte-identical слот, число live Entities и прежнего owner предмета. Base `7b38cc4b1d0914c34eb0d23a1c03c372418e87ba` → target `bf71a6dc76f71ba9267bef89ebb9d0222b196a13`; immutable read-only review **PASS**, material findings нет, triage завершён. Реальные command roundtrip и refusal сохранены focused GUT. Незавершённой работы в этом scope нет.

### Validation

- **PASS** focused console GUT: 9/9 tests, 84 asserts, process exit 0, stderr пустой; logs `.artifacts/godot_agent/gut-20261015-183829651.stdout.log` / `.stderr.log`.
- **PASS** native ParseChanged (2 scripts), logs `parsechanged-20261015-183856439`; MCP diagnostics checked/empty, 2 paths, no instantiation. Script_patch generic reload 43 не объявлялся PASS; последующие независимые native проверки прошли.
- **PASS** formatter/lint 2 paths, incremental agent validator, strict architecture (0 findings), project/task structure.

### Owner QA / blockers

Gameplay/visual **NOT_RUN**, budget 0/8; для headless persistence regression не требуются. Blockers и REVIEW_PENDING отсутствуют.
