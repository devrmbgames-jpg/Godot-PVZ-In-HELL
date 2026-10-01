# R19 — Малый инвентарь, Food и MedItem

Status: **OWNER_QA**

## Task state

### Goal
Дать игроку хранить и использовать небольшие расходники с однозначным владельцем.

### Constraints / acceptance
- This is a Feature-level tracked task.
- Зависимости: R02, R04, R08, R11.1, R18
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
This file remains authoritative.
- Item -> R_OwnedBy -> Entity with C_Inventory is sole ownership. No owner arrays/caches; packages/grabbable physical items excluded. Capacity counts stacks; each authored item maximum bounds quantity.
- Whole-stack transfer checks expected previous owner and destination capacity before mutation; canonical authored definitions determine stack compatibility. Trader/container/loot use the same transfer entry point.
- Food consumes after successful Hunger effect; MedItem waits for actual DamageResult with positive healing; Bubble Wrap calls PackageProtectionService and consumes only on an increased protection tier. Per-owner use lock prevents reentrant duplication.
- Owner removal/disable/death removes virtual items. Transfers suppress orphan cleanup during intentional rebinding. UI displays derived item state and uses existing modal input capture; world time continues.

### Review findings
- R1 FIXED: disabled-owner cleanup scans raw ownership links rather than available-owner lookup.
- R2 FIXED: pending item detachment/removal/disable releases the owner use lock; matching rejection keeps quantity.
- R3 FIXED: multi-item cleanup snapshots query results before structural removal.
- R4 FIXED (separate reviewer): disabled stored items are cleaned on owner removal/death/explicit detachment; idempotent direct Entity signal binding survives GECS disconnecting its handler on disable. Registered ownership counts disabled stacks toward capacity; use still requires availability.
- R5 FIXED: each use has a unique serial; an earlier DamageResult cannot consume a later pending use.

### Current
Implementation complete: three quantity-driven world pickups, 8-stack inventory with authored 10-item bounds, whole-stack transfer, success-only Food/Med/Wrap consumption, Tab modal view and debug conditions/tasks. Direct item relationship cleanup remains active across GECS disable; disabled stored items retain ownership/capacity but cannot be used. Next: R20 Trader and paid consumable orders reuse this contract. See `docs/inventory.md`.

### Validation
- Final relevant GUT 35/35 PASS, 377 assertions across inventory, Hunger, perception, main grab, impact balance and player melee (`tests/artifacts/r19_final_gut2.log`). Inventory alone 13/13, 106 assertions, including reentrant use, stale healing results, disabled item capacity and owner/detachment/death cleanup.
- Strict main walkthrough PASS (`inventory-20261002-071622955.log`): real ray/resolver pickup of all three items, actual UI buttons/effects, package stays physical, nested modal/close, HUD and death cleanup.
- Structure validator and diff checks PASS. Main 120-frame headless shutdown has no project errors/leaks (`r19_main_shutdown.log`); external Windows certificate-store error remains. Editor imports resolved classes; editor plugin/settings errors prevent claiming a clean editor check. Formatter unavailable.
- Separate read-only reviewer completed bounded ownership/transaction/lifecycle/UI review; R4 integrated. Main independently reviewed integration and serialized scene/input contracts.

### Owner QA / blockers
Rendered UI layout/readability, pickup visuals and table placement, gamepad navigation and consumable balance remain owner QA. Existing inventory action uses Tab/gamepad; no InputMap migration. No rendered visual engine check performed. No implementation blocker.

---

Зависимости: R02, R04, R08, R11.1, R18
Ветка/base: master / `86f91acc`.
Источники: [ТЗ 06](../docs/roadmap/06_package_damage_and_hazards.md), [ТЗ 08.1](../docs/roadmap/08_1_arrangement_extended_interactions.md), [ТЗ 11](../docs/roadmap/11_hunger_system.md), [ТЗ 12](../docs/roadmap/12_inventory_and_consumables.md), [ТЗ 16](../docs/roadmap/16_ui_and_feedback.md).

## Цель

Дать игроку хранить и использовать небольшие расходники с однозначным владельцем.

## Начать здесь

- [content/components/interaction/c_interactable.gd](../content/components/interaction/c_interactable.gd)
- [content/definitions/definition.gd](../content/definitions/definition.gd)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [x] Добавить Item definitions/runtime quantity и authoritative OwnedBy → InventoryOwner. Не использовать virtual Inventory как authority для physical slots из R11.1.
- [x] Реализовать pickup, stacking совместимых consumables, use и удаление пустого стека.
- [x] Food вызывает эффект 18, MedItem — лечение 04; списание quantity и применение результата согласованы.
- [x] Добавить Consumable "Bubble Wrap": одно использование на валидной Package применяет protection modifier из R08 одним действием и списывает один consumable; сам damage/protection расчет не дублировать в Inventory.
- [x] Добавить простой UI без authority над item state; исключить Package/Furniture из обычного Inventory.
- [x] Задать контракт transfer для Trader/container/loot, не реализуя все источники сразу.

## Критерии готовности

- Игрок подбирает Food, MedItem и Bubble Wrap, видит количество и использует их; Bubble Wrap одним действием защищает выбранную Package по contract R08.
- Два owner невозможны, использование не дублируется, quantity не отрицательна; большая Package остаётся физически в мире.

## Проверки

GUT: ownership/transfer, stack, повторное use, лечение/еда, Bubble Wrap apply/consume, cleanup; walkthrough UI. Общие команды и правила завершения — в [README](README.md).

## Границы

Без сетки размещения и полного контейнерного/loot framework. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
