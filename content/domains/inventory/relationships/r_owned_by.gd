extends Component
## Связывает виртуальный стек с единственным владельцем инвентаря; физические слоты отдельны.
## Relationship.target — Entity с C_Inventory; InventoryService/InventoryDropService меняют binding.
## Lifecycle очищает владение/стеки при потере владельца; живой dormant NPC сохраняет вещи.
class_name R_OwnedBy
