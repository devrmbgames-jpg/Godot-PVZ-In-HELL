# ТЗ 01 — Gameplay-модель GECS

> **Implementation coverage:** Cross-cutting gameplay model; foundation began in **R01** and is consumed by later R-tasks.

## Цель

Создать базовую ECS-модель, на которой строятся механики прототипа.

## Основные Entity

Предусмотреть:

- Player;
- Package;
- Customer;
- Scanner;
- Marker;
- Shelf;
- Terminal;
- Door;
- Window;
- Drawer;
- Consumable;
- Weapon;
- Hazard;
- Trader;
- SleepPoint.

Не требуется отдельный класс Entity для каждого визуального варианта.

## Основные группы Components

### Общие

- Interactable;
- InteractionTarget/Interactor;
- Health;
- Item;
- Inventory ownership;
- Damage source/receiver;
- Highlight/Prompt state.

### Player

- Controller;
- Motion;
- Look;
- Interactor;
- Grab/Carry;
- Hunger;
- Wallet;
- Phase permissions.

### Package

- PackageIdentity;
- PackageNumber;
- PackageState;
- PackageTags;
- Fragility;
- Weight;
- OrientationConstraint;
- DamageState;
- ScanState;
- OpenState.

### Customer

- CustomerIdentity;
- RequestedPackage;
- Satisfaction;
- BehaviorState;
- DialogueState;
- ChallengeDefinition/State;
- AggressionState.

## Relationships

Минимально предусмотреть связи:

```text
Package --HeldBy--> Player/NPC
Package --AssignedTo--> Customer
Item --OwnedBy--> InventoryOwner
Customer --Targets--> Player
Quest --IssuedBy--> NPC
Quest --TargetsPackage--> Package
```

Relationship должен быть authoritative связью между конкретными сущностями. Не дублировать тот же факт независимыми полями без необходимости.

## Systems

Разделить gameplay минимум на:

- Input;
- Interaction;
- Movement/Physics;
- Grab;
- Package Processing;
- Package Damage;
- Customer Flow;
- Dialogue;
- Customer Challenge;
- Combat/Damage;
- Hunger;
- Inventory;
- Day Phase;
- Economy;
- UI/Presentation.

## Расширяемость

Новые клиенты, посылки и события должны добавляться через данные и композицию, а не через один центральный скрипт с большим количеством ветвлений.

## Критерий готовности

Player, Package и Customer зарегистрированы в GECS World; системы находят их по компонентам; конкретные связи между Entity выражаются Relationships.
