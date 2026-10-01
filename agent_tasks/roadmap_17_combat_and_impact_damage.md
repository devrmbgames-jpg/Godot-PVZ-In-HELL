# R17 — Ближний бой и агрессивный Customer

Status: **OWNER_QA**

## Task state

### Goal
Дать игроку и опасному клиенту общий физический боевой сценарий.

### Constraints / acceptance
- This is a Feature-level tracked task.
- Зависимости: R04, R08, R11, R12.2, R14
- Reuse existing authoritative contracts from completed dependencies; do not duplicate them.
- Aggressive Customer must reuse the generic physical NPC/controller foundation from R12.2; R17 must not reintroduce a Customer-only locomotion/look/impact path.
- The existing `## Работы`, `## Критерии готовности`, `## Проверки`, and `## Границы` sections remain the detailed implementation specification.
- Follow Godot 4.7, GECS ownership, physics authority, and validation rules from `AGENTS.md`.

### Milestones
- [x] Reconfirm dependency completion and current production owners/contracts.
- [x] Implement the existing work checklist in small coherent milestones.
- [x] Review material changes independently of the implementation plan and resolve all R-findings.
- [x] Run final task validation according to the documented GUT/headless budget.
- [x] Record remaining owner gameplay/visual QA.

### Decisions
Do not create a parallel planning document. This file remains the authoritative state/router for the feature; source design docs are references, not task state.

R12.2 owns the generic physical NPC/Customer character foundation. R17 only adds combat/pursuit/attack behavior on top of that actor/controller contract.

NPC attacks have a separate, simple execution mechanic from Player weapon input: up to three authored melee variants and up to three authored ranged variants. Each variant supplies damage, usable range, timing/cooldown and an optional animation name. Animation method-track hooks commit the melee hit or launch the projectile once; timed execution keeps the prototype playable before attack animations are assigned. Both paths use the existing damage pipeline.

Expose an explicit attack-kind/variant request for future AI. The initial AI uses a deterministic available attack by range; tactical scoring, ability trees and complex combo systems are outside this task. Navigation, physics, ownership and damage attribution remain shared foundations.

### Current
NPC 3+3 slots, independent attack execution, animation hooks/timed fallback, swept projectiles, Player blade, customer challenge/fraud escalation, generic pursuit, persistent attribution/retaliation lookup and debug HUD implemented. R1–R6 fixed. Next queue task: [R18 Hunger / Perception](roadmap_18_hunger_and_perception.md).

### Validation
- Final Godot 4.7.1 / GUT 9.7.1: **104/104 PASS, 881 assertions**, 10 scripts; `tests/artifacts/r17_final_gut2.log`. NPC variants/animation hooks/projectiles/lifecycle, Player one-click routing/strike/own-held R08 guard, persistent combat attribution, customer/dialogue/grab/impact and all challenge regressions.
- Strict `combat` smoke **PASS**, latest `tests/artifacts/combat-20261002-062255255.log`: actual Jolt weak/heavy collisions against Player and Customer through R08; actual main dialogue acknowledgement -> light failure -> same-body NavigationAgent pursuit (including ranged-only stop distance) -> Player hit -> knife defeat -> visit completion; task/range/timers debug UI present.
- Strict `challenge_light` regression **PASS**, `tests/artifacts/challenge_light-20261002-061158786.log`; bounded aggression is now allowed to finish before the next customer.
- Direct main headless 120-frame shutdown clean except external Windows certificate-store error; `tests/artifacts/r17_main_shutdown.log`. Structure validation and diff check **PASS**. Formatter unavailable, not claimed. Headless editor imports refreshed class cache; editor plugin/settings errors are not clean editor validation.

### Review
- R1 OPEN -> FIXED: ranged projectile bypassed shooter `C_NoDamage`; copy the outgoing-damage guard on launch and cover with a real collision regression. Player weapon hit also checks the actor guard.
- R2 OPEN -> FIXED: projectile durable instigator id used customer identity; use `actor.id`, covering generic NPC and shooter removal.
- R3 OPEN -> FIXED (local review/regression): untyped empty Array in typed RID ternary errored only after shooter removal; explicitly initialize typed exclusions and assign in the live-shooter branch.
- R4 OPEN -> FIXED (main-scene smoke): a default 32-result melee overlap query was filled by warehouse scenery and omitted the nearby Customer. Select living/prop health bodies from the authoritative world, then validate actual pose, cone and first physical obstruction; no capped scenery query.
- R5 OPEN -> FIXED (local review): repeated aggression entry stopped an existing pursuit and reset its timeout. Make the already-aggressive transition idempotent; regression preserves both elapsed time and generic follow intent.
- R6 OPEN -> FIXED (local review/main smoke): ranged-only NPC pursuit used a melee fallback stop distance below its minimum firing range. Derive stop distance from the first authored melee or ranged interval midpoint; main smoke verifies ranged-only pursuit range.
- Separate reviewer delivered R1/R2, then stopped due to usage limit. Main agent completed the remaining resulting-code/scene/data/lifecycle/input review; no other material findings remain. This is partial separate-agent review plus completed main-session review, not a completed separate-agent review.

### Owner QA / blockers
No implementation blocker. Owner gameplay/visual QA: assign authored attack clips, check method-track hit/release moments, motion/telegraph feel, ranged dodging and blade readability. Check warehouse routes/physical box interference and debug panel layout at target resolution. No rendered check was performed in this task.

---

Зависимости: R04, R08, R11, R12.2, R14
Ветка/base: master / `63b340ec`; task clarification `93c8d63a`.
Источники: [ТЗ 02](../docs/roadmap/02_core_interaction_and_physics.md), [ТЗ 07](../docs/roadmap/07_customer_flow_and_delivery.md), [ТЗ 10](../docs/roadmap/10_combat_damage_health.md), [ТЗ 17](../docs/roadmap/17_vertical_slice_scenario.md), [R12.2](roadmap_12_2_customer_npc_character.md).

## Цель

Дать игроку и опасному клиенту общий физический боевой сценарий.

## Начать здесь

- [content/systems/interaction/s_grab.gd](../content/systems/interaction/s_grab.gd)
- [CharacterMotionSolver](../content/services/motion/character_motion_solver.gd)
- [R12.2 NPC foundation](roadmap_12_2_customer_npc_character.md)
- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [x] Добавить один melee/острый Weapon: окно удара, hit validation, cooldown и damage через 04.
- [x] Отдельная простая механика атак NPC: до 3 вариантов ближней и до 3 вариантов дальней атаки на NPC; authored параметры урона, дистанции, таймингов/cooldown и привязка каждого варианта к отдельной анимации.
- [x] Вызов момента удара/запуска снаряда из method track анимации; защита от повторного попадания/запуска за одну атаку, отмена при смерти/потере цели. Пока анимации не назначены, таймер обеспечивает рабочий прототип.
- [x] Явный запрос типа/индекса атаки для будущего ИИ; сейчас простой выбор доступного варианта по дистанции, без оценки выгодности, дерева способностей и комбо.
- [x] Aggressive Customer прекращает сервисный разговор, использует generic NPC controller R12.2 для pursuit/look target Player и атакует Player; имеет поражение и завершение schedule event. Один из источников aggression — обнаружение ложной Terminal отметки `TAKEN` по ТЗ 07.
- [x] Подключить уже готовый generic impact contract R08 к Player/Customer/combat props. Не реализовывать вторую формулу mass/speed/impulse, второй contact dedup или отдельный combat-only impact System.
- [x] Соблюдать приоритет tool/grab/attack из 02, сохраняя input неизменным для других потребителей.
- [x] Обеспечить cleanup target/challenge/held state при смерти и выходе из боя.
- [x] Передавать typed combat/reputation reason: обычная атака, self-defense, fraud escalation, justified retaliation. После подтвержденной неправомерной Complaint именно этого Customer Player может атаковать 7 игровых дней без reputation penalty; окно хранится persistent и не зависит от живого Node.

## Критерии готовности

- Клиент ранит Player; игрок побеждает оружием или тяжёлым предметом.
- NPC выполняет ближнюю и дальнюю атаку, поддерживает независимую привязку до трёх вариантов каждого типа к анимациям. Hit/release hook выполняет эффект ровно один раз; отсутствующая анимация не ломает прототип.
- Aggressive Customer преследует Player через тот же physical NPC body/controller, который использует сервисный Customer; смена service -> combat не заменяет Entity/physics body.
- Слабое касание не наносит урон, собственный held object не бьёт держателя; одно ЛКМ не бросает и не атакует одновременно.
- Коробки блокируют проход и остаются частью физического боя.
- Combat не применяет Reputation напрямую, но сохраняет reason/context так, чтобы future Reputation могла корректно отличить разрешенную retaliation от обычной атаки.

## Проверки

GUT: melee hit/cooldown/смерть и combat attribution; physics integration подтверждает, что Player/Customer получают impact через R08 без второго calculation path; pursuit использует R12.2 NPC intent/controller; walkthrough escalation из Light Challenge. Общие команды и правила завершения — в [README](README.md).

## Границы

Без полного арсенала и сложной боевой AI. Generic locomotion/look/physical NPC принадлежит R12.2 и здесь не дублируется. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

Проверки NPC: обе дистанции и ограничения 3+3; запуск заданного варианта; animation hit/release hook и защита от дублей; отмена по смерти/потере цели; cooldown; снаряд не проходит сквозь физические препятствия. На debug UI отображаются тип/вариант, фаза, условия дистанции и таймеры атаки/cooldown.

## Первый шаг

Implementation and agent validation complete; perform owner gameplay/animation QA. Continue queue at R18.

## Привязка анимаций NPC

- В `C_NpcCombat` заполнить до трёх ресурсов `DEF_NpcAttack` в каждом массиве `melee_attacks` / `ranged_attacks`; для каждого варианта задать `animation`, дистанции, урон и cooldown. Индексы API начинаются с 0; четвёртый вариант не запускается.
- В method track выбранной анимации вызвать `npc_attack_hit()` на Entity NPC в момент контакта/выпуска снаряда. Один и тот же hook обслуживает ближнюю и дальнюю атаку; повторный вызов не дублирует эффект.
- В конце можно вызвать `npc_attack_finished()` на NPC. Обычное завершение клипа также завершает атаку; watchdog защищает от бесконечного looping clip. Треки не должны писать физический transform NPC.
- У текущего Customer `Body/AnimationPlayer` root находится на `Body`: method track должен адресовать родительский Customer (`..` относительно root), а не AnimationPlayer. Locomotion Idle/Walk не перебивает активную attack animation.
- Для будущего ИИ доступен `NpcAttackService.start(npc, C_NpcCombat.Kind.MELEE/RANGED, index)`. Живая цель хранится только в `R_CombatTarget`; перед запуском проверяются дистанция, линия, фаза и cooldown. Пока клип отсутствует, authored таймер обеспечивает рабочее исполнение.
