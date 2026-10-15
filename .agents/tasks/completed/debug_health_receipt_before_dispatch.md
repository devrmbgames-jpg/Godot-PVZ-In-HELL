# QA-HP01 — HP до dispatch в диагностике debug-команд

Status: **DONE**
Priority: **P2**
Baseline: `dev` / `438fd5f0d4a1d10dafe69d86180ad1c2a1f4e34f`

## Task state

### Goal

DebugHealthService должен сохранять значения `hp_before` до DamageRequestService.submit: native PER_CALLBACK вправе изменить здоровье inline до возврата. Scope: scalar diagnostic context `_submit` и focused regression в test_console_gameplay; combat arithmetic, request/result timing и смысл success не меняются.

Дефект найден при [DOC01](pvz_code_documentation_quality.md); это отдельное исправление поведения.

### Reproduction

Минимальный World с реальным O_Damage: HP 80/100, damage 5 сразу меняет current на 75; adapter ошибочно пишет `hp_before=75.0/100.0`. Следующее heal 5 возвращает HP 80, но пишет `hp_before=80.0/100.0` вместо 75/100. Причина — чтение Resource после event dispatch.

Baseline GUT: `utils/godot_agent.ps1 -Action GUT -TestPath res://tests/gut/test_console_gameplay.gd` — **FAIL**, 9/10 tests, 88/90 asserts; падают только два новых ожидания hp_before, inline mutation и прежние тесты проходят. Logs `.artifacts/godot_agent/gut-20261015-184433493.stdout.log` / `.stderr.log`, stderr пустой.

### Acceptance

- [x] Реальный PER_CALLBACK reproduction подтверждает оба неправильных pre-values.
- [x] Scalar HP/max/ID diagnostic context снят до submit; после dispatch adapter не перечитывает live target для этих строк.
- [x] Focused GUT и native parser/MCP/style/static gates проходят.
- [x] Отдельный immutable checkpoint/review/triage завершён.

### Current

Scalar ID/current/max сняты перед submit; итоговый message/success/request pipeline не меняются. Base `438fd5f0d4a1d10dafe69d86180ad1c2a1f4e34f` → target `428ea674dd07d95a3569fd5e4983c1927e1a22ed`. Immutable read-only review **PASS**, material findings нет; triage завершён. Reviewer тесты не запускал, validation ниже выполнена основным агентом.

### Validation

- **PASS** focused console GUT: 10/10 tests, 90 asserts, process exit 0, stderr пустой; logs `.artifacts/godot_agent/gut-20261015-184609321.stdout.log` / `.stderr.log`.
- **PASS** native ParseChanged (2 scripts), logs `parsechanged-20261015-184630292`; MCP 2 paths checked/empty, no instantiation.
- **PASS** formatter/lint 2 paths, incremental agent validator, strict architecture (0 findings), project/task structure и scoped whitespace.

### Owner QA / blockers

Gameplay/visual **NOT_RUN**, budget 0/8; для headless diagnostic regression не требуются.
