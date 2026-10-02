# R20 — Вечер, торговец, заказы и квест

Status: **OWNER_QA**

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
- [x] Reconfirm dependency completion and current production owners/contracts.
- [x] Implement the existing work checklist in small coherent milestones.
- [x] Independently review material changes and resolve all R-findings.
- [x] Run final task validation according to the documented GUT/headless budget.
- [x] Record remaining owner gameplay/visual QA.

### Decisions
This task is authoritative; implementations reuse WalletService, InventoryService, CustomerFlowService and PackageRegistrationService.
- Trader sells Food/Med/Wrap during Evening. Terminal orders work during Morning/Evening, debit once and persist next-Morning PendingDelivery; physical fulfillment/restart belongs to R21.
- Stable producer operation IDs deduplicate receipts and wallet operations; different item/quantity/mode under the same ID conflicts. Validate before mutation, no yield inside commit. Inventory capacity/funds rejection grants nothing.
- Item market price and Package content_item_key/content_quantity are authored; accounting value remains independent.
- Quest candidates are registered, unresolved future warehouse packages (including late equipment). Quest deadline is its target visit arrival day or later; completion requires actual Player denial, failure actual delivery, ignored explicitly declined, expired after deadline without completion. All ordinary refusal/complaint/settlement consequences remain. Persistent records store IDs, day and outcomes; live IssuedBy/TargetsPackage use Relationships.

### Current
Implementation complete: physical external Trader with NavigationAgent, evening purchases, Terminal Morning/Evening paid orders, identity-bound refusal quest and debug task/deadline/delivery UI. Backend milestone `9da353db`; final integration independently reviewed with no material findings. Next: R21 autosave and exactly-once next-Morning fulfillment.

### Validation
- Final relevant GUT 73/73 PASS, 662 assertions across commerce, quest, inventory, wallet, customer flow and dialogue (`tests/artifacts/r20_final_gut.log`). Backend 7/7 and quest 7/7 cover replay/conflict, funds/capacity, record copies and every actual quest outcome/deadline; ordinary refusal penalty remains independent from reward.
- Strict `evening_meta-20261002-074451980.log` PASS: actual main scene, phase transitions, Trader physical/nav contracts, F ray interaction, purchases, quest acceptance, Terminal modal handoff/orders, debug deadlines and capture restoration. Actor repositioning is a fixture; walking route was not visually verified.
- Headless main shutdown has no project errors/leaks; external Windows certificate-store error remains. Structure validator and diff checks PASS. Editor import resolved classes without project script errors; editor settings/plugin errors prevent a clean editor claim.
- Separate read-only reviewer found no material issues in transaction/quest ownership, actual outcomes, modal UI and scene contracts. Reviewer ran no tests.

### Owner QA / blockers
Ручные проверки и результаты игроков: [сценарий QA](../qa_tasks/commerce_and_persistence.md).

Игровая приёмка ожидается; перенос не означает успешного прохождения. Реализация и автоматические доказательства остаются в этой задаче.

---

Зависимости: R06, R10, R12, R19
Ветка/base: master / `c11dea8b`.
Источники: [ТЗ 05](../docs/roadmap/05_scanner_terminal_marker.md), [ТЗ 14](../docs/roadmap/14_evening_meta_scaffold.md), [ТЗ 17](../docs/roadmap/17_vertical_slice_scenario.md).

## Цель

Добавить минимальную вечернюю подготовку к следующему дню.

## Начать здесь

- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)
- [content/definitions/definition.gd](../content/definitions/definition.gd)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [x] Создать маленькую внешнюю зону и Trader с Food, MedItem и одним utility consumable. Item definitions должны иметь рыночную цену, которую можно сопоставить с учетной стоимостью содержимого Package из ТЗ 07.
- [x] Покупка проверяет Money и атомарно выдаёт товар через Inventory contract.
- [x] Terminal order создаёт PendingDelivery и однократно списывает/резервирует оплату; предусмотреть заказ расходников в Morning, как разрешает 03.
- [x] Добавить definitions LabelPrinter/Cart/BetterScanner/StorageUpgrade без реализации улучшений.
- [x] Создать Quest «Не выдавай посылку №XXXX» со связями IssuedBy/TargetsPackage и исходами Completed/Failed/Ignored/Expired; однозначно определить срок и успех. Quest не должен обходить общий refusal/Complaint/settlement contract: Player всё ещё несет обычные последствия отказа, если Quest отдельно их не компенсирует.

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
