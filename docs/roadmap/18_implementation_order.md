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
- Marker;
- numbered Shelves;
- registration.

Результат: Player принимает и самостоятельно организует поставку.

---

## Этап 5 — Package Properties

Реализовать:

- Normal;
- Fragile;
- Heavy;
- Liquid;
- Opening;
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
- correct/wrong package;
- Satisfaction;
- leaving.

Результат: обычного Customer можно полностью обслужить.

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
- PendingDelivery.

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
