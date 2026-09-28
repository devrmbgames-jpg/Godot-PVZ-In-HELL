# R20 — Вечер, торговец, заказы и квест

Status: **PLANNED**

## Task state

### Goal
Добавить минимальную вечернюю подготовку к следующему дню.

### Constraints / acceptance
- This is a Feature-level tracked task.
- Зависимости: R06, R10, R12, R19
- Reuse existing authoritative contracts from completed dependencies; do not duplicate them.
- The existing `## Работы`, `## Критерии готовности`, `## Проверки`, and `## Границы` sections remain the detailed implementation specification.
- Follow Godot 4.7, GECS ownership, physics authority, and validation rules from `AGENTS.md`.

### Milestones
- [ ] Reconfirm dependency completion and current production owners/contracts.
- [ ] Implement the existing work checklist in small coherent milestones.
- [ ] Independently review material changes and resolve all R-findings.
- [ ] Run final task validation according to the documented GUT/headless budget.
- [ ] Record remaining owner gameplay/visual QA.

### Decisions
Do not create a parallel planning document. This file remains the authoritative state/router for the feature; source design docs are references, not task state.

### Current
Not started under the lean workflow. Next: verify dependencies in `task_history.md` and current code, then choose the first bounded implementation milestone from the existing work list.

### Validation
Not run for this task under the lean workflow.

### Owner QA / blockers
No new blocker is recorded. Any unmet dependency discovered during startup moves the task to `BLOCKED` or `DEFERRED` with the exact dependency named.

---

Зависимости: R06, R10, R12, R19
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 05](../docs/roadmap/05_scanner_terminal_marker.md), [ТЗ 14](../docs/roadmap/14_evening_meta_scaffold.md), [ТЗ 17](../docs/roadmap/17_vertical_slice_scenario.md).

## Цель

Добавить минимальную вечернюю подготовку к следующему дню.

## Начать здесь

- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)
- [content/definitions/definition.gd](../content/definitions/definition.gd)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [ ] Создать маленькую внешнюю зону и Trader с Food, MedItem и одним utility consumable. Item definitions должны иметь рыночную цену, которую можно сопоставить с учетной стоимостью содержимого Package из ТЗ 07.
- [ ] Покупка проверяет Money и атомарно выдаёт товар через Inventory contract.
- [ ] Terminal order создаёт PendingDelivery и однократно списывает/резервирует оплату; предусмотреть заказ расходников в Morning, как разрешает 03.
- [ ] Добавить definitions LabelPrinter/Cart/BetterScanner/StorageUpgrade без реализации улучшений.
- [ ] Создать Quest «Не выдавай посылку №XXXX» со связями IssuedBy/TargetsPackage и исходами Completed/Failed/Ignored/Expired; однозначно определить срок и успех. Quest не должен обходить общий refusal/Complaint/settlement contract: Player всё ещё несет обычные последствия отказа, если Quest отдельно их не компенсирует.

## Критерии готовности

- В Evening игрок покупает расходник, делает заказ на завтра и получает quest на конкретную Package.
- Для хотя бы одного содержимого Package учетная стоимость и рыночная цена могут различаться, чтобы будущая дилемма присвоения была data-driven, а не hard-coded.
- Денег/товаров/заказов не становится больше от повторного события; quest использует identity, а не текст номера.
- Состояния готовы к сериализации, не зависят от живых Node references.

## Проверки

GUT: покупки/недостаток денег, PendingDelivery, каждый исход quest; gameplay walkthrough внешней зоны и Terminal. Общие команды и правила завершения — в [README](README.md).

## Границы

Физическая доставка следующего утра и устойчивость через перезапуск проверяются в 21; без полной экономики/дерева upgrades. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
