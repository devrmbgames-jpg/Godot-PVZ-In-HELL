# Refactoring v2.17 — Combat, attacks и projectiles

Status: **PLANNED**

Зависимости: service inventory завершён.

## Goal

Вернуть scheduled combat progression в Systems, сохранив Geometry, attribution и request boundaries как отдельные helpers/services.

## Scope

- `S_NpcCombat / NpcAttackService.tick`;
- `S_CombatProjectile / ProjectileService.tick`;
- `S_PlayerMelee / CombatService.tick_strike`;
- `S_CustomerCombat / CustomerCombatService.tick`;
- launch/start/cancel/hit explicit commands;
- `CombatGeometry`, `DamageRequestService`, attribution.

## Direction

- projectile movement/lifetime/raycast = System;
- attack phase/cooldown progression = System;
- launch/start/cancel = explicit command Service допустим;
- Geometry остаётся helper;
- damage submission остаётся typed request boundary.

## Acceptance

Combat Systems содержат реальное scheduled behavior, а не forwarding wrappers.
Ни один Service не владеет combat frame clock.

## Validation

NPC attacks, player melee, projectile/damage профильные tests + parser.
