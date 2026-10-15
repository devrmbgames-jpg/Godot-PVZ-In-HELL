# SMOKE-PD01 — Исправить тип perception argument в personal delivery smoke

Status: **DONE**
Priority: **P2**
Baseline: `dev` / `0ac28ff7919729258be27af7e3390e65fafeb4fc`

## Task state

### Goal / scope

Восстановить компиляцию [personal_delivery_dialogue_smoke.gd](../../../tests/smoke/personal_delivery_dialogue_smoke.gd): передавать существующий NpcRecord в действующий `NpcPerceptionService.can_see`, не его DEF_NpcArchetype. Production perception rules, default saves, сцены и игровой баланс не менять.

### Evidence

- Live MCP editor log и точечный `pvz_gdscript_path_diagnostics` подтверждают parse FAIL: line 173, argument 3 должен быть NpcRecord, передан DEF_NpcArchetype.
- Smoke blob `a939c424a8d57e3200737de58889994d48b21b6c` одинаков на `8d38ada79fe25d4cc03290ca99996788bb3d93b5` и baseline выше. Ошибка независима от DOC01 comment-only batch; production API также им не менялся.
- `_ambush` уже разрешает `person: NpcRecord`; can_see читает его profile и actor-specific trait rules. Новый resolver или nullable semantics не нужны.

### Acceptance

- [x] Smoke использует актуальный typed API; native parser и MCP diagnostics PASS.
- [x] Relevant local regression выполнен; обе фазы smoke PASS, runtime сбоя не обнаружено.
- [x] Formatter/static gates и immutable-SHA reviewer/triage завершены.

### Current / next

Заменён только аргумент person.profile → person; существующий NpcRecord уже содержит profile и actor-specific traits. Scope завершён, review/triage PASS; перенести этот файл в completed/.

### Validation / review

Baseline native MCP parse: **FAIL** (подтверждённый дефект).

- PASS: native MCP script_patch, reloaded=true, diagnostics checked/empty; независимый path diagnostics — checked, error 0, no instantiation.
- PASS: native ParseFiles; `.artifacts/godot_agent/parsefiles-20261015-172351361.stdout.log` / `.stderr.log`.
- PASS: реальный smoke write и restore двумя headless процессами, каждый exit 0 и собственный completion marker; `.artifacts/godot_agent/personal-delivery-argument-write.stdout.log` / `.stderr.log` и `personal-delivery-argument-restore.stdout.log` / `.stderr.log`. Только собственный user://personal_delivery_dialogue_smoke.pvzh; restore удаляет его.
- PASS: incremental formatter/lint, agent validator, project structure; production perception source и scene не меняются.
- Review: **PASS**, base `0ac28ff7919729258be27af7e3390e65fafeb4fc` → target `45ddf2e8bfbd4cb83a40c0bdee27621a106aae88`, read-only immutable Git snapshot; material findings нет, triage main завершён. ARCHITECTURE/STYLE PASS, reviewer VALIDATION NOT_RUN (проверки выполнял main). Visual/gameplay feel: **NOT_RUN, 0/8**.

### Owner QA / blockers

Для typed smoke adapter fix визуальная приёмка не требуется. Unresolved findings/blockers нет.
