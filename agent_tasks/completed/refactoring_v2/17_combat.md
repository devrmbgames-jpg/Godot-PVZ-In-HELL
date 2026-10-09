# Refactoring v2.17 — Combat, attacks и projectiles

Status: **DONE**

Зависимости: [16_npc_route_service_role.md](16_npc_route_service_role.md), [10_service_inventory.md](10_service_inventory.md).

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

## Result / Current

17.A–17.D выполнены: S_PlayerMelee владеет strike clock/scan, S_NpcCombat — cooldown/phases/native animation watchdog, S_CombatProjectile — flight/TTL/full-segment ray/retirement, S_CustomerCombat — isolated legacy escalation/pursuit. Четыре Service clock API удалены, все callers и tests переведены на actual Systems. Explicit target/start/cancel/effect/hit/launch, Geometry и typed damage attribution сохранены.

Queued execution захватывает identity Component и generation атаки; отмена/повторный запуск той же Definition и reentrant damage consumers не могут продвинуть или воскресить заменённую атаку. Projectile terminal retirement повторно проверяет регистрацию после damage publication. Flight принадлежит nonphysical Node3D; Jolt body authority не изменена.

MeleeWeaponPresentation перенесён в content/presentation/combat с сохранённым UID и manual AnimationPlayer mapping. Authoring/timing/balance не менялись. Headless combat fixture обновлён под текущий CharacterBody Player, отдельный legacy visit и compact HUD; assertions полного diagnostic и реального боя сохранены.

## Acceptance / Validation result

- PASS: initial профильный GUT, 6 scripts, 101/101 tests, 737 assertions (npc attacks, player melee, attribution, challenge light, breakable doors, district native BT lifecycle).
- PASS: final focused regressions, 30/30 tests, 227 assertions; шесть новых случаев MANUAL replacement/reentrant restart/lethal cancellation/automatic selection/projectile state replacement.
- PASS: changed-script Godot parser, 18 project-owned files, 0 failures.
- PASS: actual main-level headless combat smoke, including Jolt impacts, legacy light escalation, pursuit, damage and player self-defense.
- PASS: architecture (12 remaining lexical findings), project structure, persistence baseline, preflight and git diff --check. Removed all eight combat execution baseline allowances; no old tick caller/path alias remains.
- Rendered gameplay / subjective visual QA не запускались; сохранённые authored clips и timing не требуют нового product choice.

Next: 18_challenges.md. Phase 3 не начинать.
