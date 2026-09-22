# ТЗ 10 — Урон, здоровье и базовый бой

> **Implementation coverage:** Implementation coverage: common damage/health foundation **R04** (completed), combat/aggressive Customer **R17**.

## Цель

Позволить опасному Customer/event перейти в физический конфликт.

## Health

Player и combat-capable Customer имеют:

- current health;
- maximum health;
- damage handling;
- defeat/death state.

## Единый Damage Pipeline

Минимальные источники:

- melee;
- physical impact;
- Explosion;
- ToxicLeak;
- monster attack.

Все источники должны проходить через общий damage contract.

## Physical Impact Damage

Быстро движущийся тяжелый RigidBody может нанести damage.

Учитывать минимум:

- массу;
- относительную скорость столкновения;
- минимальный порог события.

Слабое касание не наносит combat damage.

## Player Attack

Для прототипа достаточно одного melee/острого Weapon.

Если Player сейчас использует held object как throwable, Throw имеет приоритет над обычной атакой.

## Aggressive Customer

Customer может перейти в Aggressive после:

- сильного недовольства;
- failed Challenge;
- обнаруженной махинации с Package/ложной отметки `TAKEN`;
- scripted event.

В Aggressive:

- обычный сервисный Dialogue прекращается;
- Customer преследует/атакует Player;
- Player может защищаться;
- физические предметы мира остаются частью боя.

## Reputation exception hook

ТЗ 07 допускает редкую неправомерную Complaint от Customer, которому Package была фактически выдана.

После подтверждения такой ложной Complaint Player получает право атаковать **этого конкретного Customer** без потери будущей Reputation в течение 7 игровых дней.

Combat system не должен сам вычислять Reputation. Он должен передавать typed context/reason, позволяющий будущей Reputation системе отличить:

- обычную неспровоцированную атаку;
- self-defense;
- разрешенное retaliation window после подтвержденной ложной Complaint.

Истечение окна не должно зависеть от того, загружен ли Customer Entity в сцене.

## Критерий готовности

Customer может ранить Player; Player может победить его Weapon или тяжелым предметом; Hazard и physics impacts используют ту же модель Health/Damage.
