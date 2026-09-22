# ТЗ 18 — Порядок реализации для ИИ агентов

## Принцип

Каждый этап должен давать маленький проверяемый gameplay результат.

Не масштабировать контент до полного прохождения vertical slice.

## Этап 1 — GECS Gameplay Foundation

Реализовать:

- World integration;
- Player;
- Package;
- Interaction Target;
- Prompt.

Результат: Player видит Package и может выбрать ее как interactable.

---

## Этап 2 — Physical Interaction

Реализовать:

- Grab;
- Release;
- Throw;
- Rotate;
- Carry Penalty.

Результат: физическими объектами можно манипулировать и блокировать пространство.

---

## Этап 3 — Day Phase Cycle

Реализовать:

- Morning;
- Day;
- Evening;
- Night;
- переходы.

Результат: пустой игровой цикл проходит все четыре фазы.

---

## Этап 4 — Package Workflow

Реализовать:

- Package state;
- Scanner;
- Terminal;
- registration;
- reusable Package numbering: `№001`, `№002`, ... using the smallest currently free base number across days;
- [RM06.1 — Inspector-first компоненты, Carry/две руки и Push](06_1_interaction_hands_carry_push.md);
- Marker;
- numbered Shelves.

RM06.1 выполняется после Scanner/Terminal и до Marker/Shelves, чтобы инструменты сразу строились на стабильном contract двух рук, независимого Carry и Push.

Результат: Player принимает и самостоятельно организует поставку, а физические tools используют единый slot/input contract.

---

## Этап 5 — Package Properties

Реализовать:

- Normal;
- Fragile;
- Heavy;
- Liquid;
- Opening;
- количественный Package HP/Integrity;
- weak / medium / strong impact severity;
- Bubble Wrap protection modifier;
- Damage.

Результат: тип коробки меняет правила обращения.

---

## Этап 6 — Hazard Pipeline

Реализовать:

- ToxicLeak;
- Explosion;
- common Damage Pipeline.

Результат: содержимое Package может стать физической угрозой.

---

## Этап 7 — Customer Base

Реализовать:

- arrival;
- lifecycle;
- RequestedPackage;
- DeliveryCounter;
- correct/wrong/opened/damaged package;
- actual delivery outcome отдельно от Terminal declaration;
- `Забрал / Отказался / Потеряна`;
- Customer voluntary refusal и Player denial;
- Complaint/dispute records;
- Satisfaction;
- leaving.

Результат: Customer service поддерживает как честную выдачу, так и отказ/потерю/ложную отметку с типизированным исходом и будущими последствиями.

---

## Этап 7.5 — Arrangement / Extended Interaction

Реализовать [ТЗ 08.1](08_1_arrangement_extended_interactions.md):

- prolonged interaction + progress/reset policies;
- Door lock/access requirements;
- reusable physical storage slots;
- Carry PlacementArea;
- Hammer Fix/Unfix для мебели;
- support-neighbor unfix safety.

Результат: Player может физически организовывать пространство и предметы, а инструменты/двери/мебель используют общие interaction contracts.

---

## Этап 8 — Dialogue

Реализовать:

- lines;
- choices;
- conditions;
- package number;
- simple riddle.

Результат: Customer service начинается через Dialogue.

---

## Этап 9 — Environment Interactables

Реализовать:

- Doors;
- Windows;
- Drawers;
- Lights.

Результат: окружение готово для физических и horror challenges.

---

## Этап 10 — Challenge Framework

По порядку:

1. Light On/Off;
2. Don't Look или Keep Looking;
3. Floor Hazard.

Результат: минимум три Customer Event используют общий Challenge Framework.

---

## Этап 11 — Combat

Реализовать:

- Health;
- Melee;
- Aggressive Customer;
- Physical Impact Damage.

Результат: Customer Event может перейти в бой.

---

## Этап 12 — Hunger

Реализовать:

- progression;
- Food;
- movement/damage modifiers;
- Starving perception.

---

## Этап 13 — Inventory

Реализовать:

- small item ownership;
- stacks;
- Food;
- MedItem;
- UI.

---

## Этап 14 — Evening / Meta Scaffold

Реализовать:

- Money;
- Package value/settlement operations 100/120/150/200%;
- typed future Reputation reasons;
- Trader;
- next-day order;
- upgrade definitions;
- one Package Quest.

---

## Этап 15 — Night / Persistence

Реализовать:

- Sleep;
- daily reset;
- next Morning;
- Save/Load;
- PendingDelivery;
- active Package across days;
- unresolved Complaint/dispute;
- late Customer arrival and 7-day retaliation window.

---

## Этап 16 — Vertical Slice Integration

Пройти сценарий из `17_vertical_slice_scenario.md`.

На этом этапе не добавлять новые крупные mechanics. Исправлять только разрывы core loop, UX и системные конфликты.

## Финальный критерий

Игрок способен самостоятельно пройти:

```text
Morning Receiving
→ Day Customer Service + Horror Events
→ Evening Preparation
→ Night Sleep
→ Next Morning
```

Все основные действия происходят через единый физический мир и GECS gameplay state.
