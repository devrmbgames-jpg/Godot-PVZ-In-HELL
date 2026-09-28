# R11.1 — Prolonged foundation / milestone 1

Status: **DONE**  
Owner task: [R11.1](../roadmap_11_1_extended_interactions_and_arrangement.md)

## Task state

### Goal
Establish the data/session/progress foundation for prolonged interactions without runtime wiring.

### Constraints / acceptance
Keep timing/reset policy data-driven; Relationships own live session bindings; readiness and effect completion remain separate.

### Milestones
- [x] Timing definition and reset policy.
- [x] Target-owned progress state.
- [x] Actor/source/target Relationship session data.
- [x] Pure progress solver and focused test coverage prepared.

### Decisions
The detailed ownership rules below are durable output of M1 and remain authoritative for later milestones.

### Current
Milestone complete. R11.1 continues in its root task with M2 runtime integration.

### Validation
Seven focused GUT cases are prepared. Execution is deferred to the owner task's final validation cadence.

### Owner QA / blockers
None for this completed milestone.

---

## Этапы и модель владения

1. **Выполнено:** timing definition, target-owned progress record/component, session relationship data и pure progress solver. Покрытие GUT подготовлено; исполнение отложено до финальной проверки R11.1.
2. Подключить prolonged к существующему resolver/input/focus и HUD; атомарный completion и lifecycle cleanup.
3. Access requirements и общий open/close/translate contract.
4. Physical slots и collision-validated Carry placement.
5. Hammer anchor/unfix, восстановление physics state, support query; итоговые GUT + physics smoke.

### Владение

- Progress принадлежит affected target: `C_ProlongedInteraction.actions`, одна `ProlongedInteractionProgress` на стабильный `action_id`. Definition неизменяемая; HUD только читает.
- Активная сессия: `R_ProlongedOn` actor → affected target. Если action source является отдельным tool, `R_ProlongedUsing` actor → source. Entity-ссылки не дублируются в Components. Сервис следующего этапа гарантирует одну сессию на actor/target и освобождает relations/capture token при любом выходе.
- Продолжительность по умолчанию 1.5 s; default reset INSTANT. DECAY задаётся в долях полного progress за секунду независимо от duration. ON_COMPLETE сохраняет незавершённый progress и обнуляет его только после успеха. NEVER после успеха остаётся одноразово завершённым.
- Одно непрерывное удержание допускает один completion. Даже ON_COMPLETE требует release/interruption перед повтором, чтобы held input не вызывал повторные эффекты без нового намерения.
- `advance()` возвращает готовность, а не выполнение эффекта. Следующий executor в одном синхронном command-boundary шаге повторно проверяет actor/source/target/focus, выполняет effect, затем вызывает `commit_success()`. При отказе — `interrupt()` и освобождение participation. Готовность сама по себе не является completion.
- Physical storage: будущая item → slot-owner Relationship со slot key, отдельная от hand/carry; одна Entity на слот. Transfer полностью валидируется до смены отношений. Placement не создаёт ownership relation: occupancy из physics overlap, collision/sweep validation до release Carry и однократного выравнивания тела.
- Anchoring: состояние target хранит единый обратимый snapshot freeze/grab/physics; перед fix проверяется неподвижность/отсутствие ownership/capture. Unfix проверяет фактическую поддержку коротким query. Детали реализации — этап 5.

### Проверка первого этапа

- `python utils/validate_project_structure.py` — PASS.
- `git diff --check` — PASS.
- Optional formatter unavailable; GUT, Godot и визуальные проверки этого этапа не запускались.
- `tests/gut/test_prolonged_progress.gd`: 7 подготовленных тестов для duration/reset/one-shot/invalid input.

### Продолжить

`InteractionActionResolver.handle_input/_execute_slot`: добавить held intent для E/F без изменения приоритета рук/Carry; подключить опциональную timing definition к `DEF_InteractionAction` и один lifecycle executor перед UI. Новые data contracts пока не подключены к runtime — обычные actions сохранены без изменений.

Сохранить пользовательские изменения, существовавшие до задачи: `addons/gecs`, customer schedule, package debris scene, `main_level.tscn` и untracked UID-файлы R09/R11. Не включать их в коммиты этапа.
