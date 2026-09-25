# R09 — Generic Toxic Area / Explosion и активация из Package

Status: implementation ready; awaiting user runtime/visual acceptance (R09.1-R09.4 committed in stages)
Зависимости: R04, R08
Base: master / e9ecb7f.
Источники: [ТЗ 06](../docs/roadmap/06_package_damage_and_hazards.md), [ТЗ 10](../docs/roadmap/10_combat_damage_health.md), [ТЗ 17](../docs/roadmap/17_vertical_slice_scenario.md).
Подтверждённое архитектурное решение: ToxicLeak/Explosion — самостоятельные Entity/эффекты. Package — только один из возможных инициаторов. В будущем те же эффекты должны создавать взрывная бочка, токсичный Customer, ловушка или scripted ability без модификации hazard logic.

## Цель

Создать два переиспользуемых hazard-объекта и отдельный generic контракт их появления. Package-specific код только переводит существующие PackageLifecycleEvent в этот контракт. Вся арифметика HP остаётся в O_Damage через DamageRequestService; физические импульсы принадлежат Godot/Jolt.

## Начать здесь

- [PackageLifecycleEvent](../content/contracts/packages/package_lifecycle_event.gd) и [PackageLifecycle](../content/services/packages/package_lifecycle.gd);
- [O_PackageDamage](../content/observers/gameplay/o_package_damage.gd), [O_PackageOpening](../content/observers/gameplay/o_package_opening.gd), [S_LiquidTilt](../content/systems/gameplay/s_liquid_tilt.gd);
- [DamageRequestService](../content/services/damage/damage_request_service.gd) и [damage_request.gd](../content/contracts/damage/damage_request.gd);
- [DEF_Package](../content/definitions/gameplay/packages/def_package.gd) и [R08 contract](../docs/damage_impact.md).
- [e_grabbable_body.gd](../content/entities/props/e_grabbable_body.gd) и [s_motion.gd](../content/systems/motion/s_motion.gd) читать только перед физическим этапом Explosion.

Имена новых типов ниже — проектируемые, а не утверждение о существовании файлов. Не создавать параллельный R09: канонический ID — R09.

## Архитектурный контракт

### 1. Источник и эффект независимы

- Trigger owner (Package/Barrel/Customer/Trap) публикует generic `HazardSpawnRequest`, а не инстанцирует напрямую токсичную зону или взрыв.
- `HazardSpawnRequest` содержит автономный `PackedScene`, world transform, устойчивый origin_id и необязательный origin/instigator; definition/lifetime/ownership принадлежат самой hazard-сцене.
- `O_PackageHazard` — только адаптер `PackageLifecycleEvent.EVENT` → `HazardSpawnRequest`. Он не вычисляет периодический урон, радиус взрыва или физические импульсы. В будущем barrel/customer adapters пользуются **тем же** generic request и фабрикой.
- Настройки эффекта остаются `Resource`/Definition внутри автономной hazard-сцены. `DEF_Package` не классифицирует эффект: только `hazard_on_damaged: PackedScene` и `hazard_on_destroyed: PackedScene`.
- Дедупликация принадлежит производителю (например, одноразовая активация для конкретной посылки и hazard), плюс фабрика не должна дважды создавать instance по тому же одноразовому request ID. Не запрещать независимые повторные активации от других владельцев и способности Customer.
- `DamageRequest.source` — фактическая hazard Entity. `instigator` — actor/owner, вызвавший её. Сохранять устойчивую атрибуцию, даже если исходная посылка уже удалена. Не обходить source-side `C_NoDamage`: решать/пропагировать запрет при генерации независимого эффекта, чтобы запрещённый emitter не причинял урон через созданный им hazard.

### 2. Самостоятельные gameplay Entity

- `E_ToxicArea` + `C_ToxicArea` (имена примерные): собственный `Area3D`/область, периодический damage tick, радиус, время жизни, параметры через definition и optional policy привязки к владельцу. Не зависеть от существования Package после спавна.
- `E_Explosion` + `C_Explosion`: отдельная короткоживущая Entity с world pose и одним атомарным resolution. Создать её можно без Package: например, при смерти взрывной бочки или из способности Customer.
- Обе Entity имеют независимый lifecycle, состояние однократности/интервалов и cleanup. VFX/SFX — вторичные presentation hooks, а не отдельный authority HP.
- Для токсичного Customer допускается *прикреплённая* зона: explicit follow/attach relation/компонент и выбранное поведение при исчезновении владельца (detach or despawn). Для протекшей Package — независимая мировая зона, которая может пережить удаление исходной коробки.
- Persistence/cleanup policy (включая `persistent` для будущего R21) находится в данных hazard, не в Package.

## Этапы реализации

### R09.1 — Generic spawn и package adapter

- [x] Создать generic typed `HazardSpawnRequest`, authored hazard definitions/prefabs и единственный безопасный dispatcher/factory.
- [x] Подготовить две независимые Entity/prefab с data-only компонентами и lifecycle/attribution.
- [x] `O_PackageHazard` подписывается на `PackageLifecycleEvent.EVENT` и при `Damaged`/`Destroyed` спавнит напрямую соответствующую scene-ссылку из `DEF_Package`; hazard enum/type отсутствует.
- [x] Повторные переходы `Leaking → Destroyed` не спавнят вторую зону для одноразовой Package. Несколько разных посылок дают независимые эффекты.
- [ ] Проверить, что прямой generic spawn без Package работает; запланировать подключение будущих Barrel/Customer через этот контракт. [NOT RUN: user-owned acceptance; standalone smoke fixture prepared.]

### R09.2 — ToxicArea

- [x] Система с конкретным GECS query по компоненту зоны; периодический tick с независимым состоянием каждой области и ограниченным временем жизни.
- [x] Получатели выбираются spatial query/overlap; допускаются Player и будущие Customer с `C_Health` согласно authored eligibility.
- [x] Урон идёт только через `DamageRequestService.submit()` с `DamageRequest.Type.TOXIC`. Учитывать source-side запрет и валидность target; один непрерывный overlap не превращается в бесконечный damage per frame.
- [x] Независимый pool/зона сохраняется или очищается по собственному lifecycle; optional attached variant использует generic owner-follow, а не Package logic.

### R09.3 — Explosion

- [x] Одноразовая atomic resolution через generic Explosion Entity/систему, независимо от класса инициатора.
- [x] Spatial radius/затухание задаются ресурсом; установить явную LOS/obstacle policy (MVP: один raycast по цели; blocked полностью, без сложного частичного укрытия).
- [x] Radial HP damage — только typed `DamageRequest.Type.EXPLOSION` через сервис. Физические тела получают `apply_central_impulse`/соответствующий Godot/Jolt impulse, включая тела без `C_Health`; не присваивать напрямую скорость.
- [x] Идемпотентный single-shot, устойчивость к удалению origin/target, отсутствие self-recursion/непредусмотренного бесконечного взрывного цикла.
- [x] Цепные реакции возможны через обычные typed damage/lifecycle события и отдельные one-shot guards; не кодировать Package-specific branch внутри Explosion.

### R09.4 — Lifecycle, регрессии и приёмка

- [x] Очистка временных Hazard и cleanup world/physics references после окончания lifetime, disable либо удаления origin согласно выбранной policy.
- [x] Data-driven persist flag и контракт будущего nightly reset (реальная R21 serialization вне R09).
- [x] Readable MVP visualization для обеих самостоятельных Entity; gameplay authority не переносить в UI.
- [x] Debug acceptance HUD: постоянный HP игрока; при выделении Package показывать authored tags/hazard и шкалу HP, читая только существующие `C_Health` / `C_Package.definition`.
- [x] Финальная GUT-проверка: независимый spawn без Package, one-shot активация, Leaking+Destroyed dedup, tick interval, радиус/LOS, удаление исходного объекта, cleanup, источник/instigator, запрет исходящего damage и несколько активных зон. [PASSED: user-reported 2026-09-25.]
- [ ] Финальная physics/user-проверка: взрыв реально разбрасывает тела; ToxicArea наносит периодический урон; Barrel/Customer fixtures создают те же эффекты без второй реализации; существующий R08 Impact/Grab/Package pipeline не сломан. [PENDING: debug HUD added for visible Player/Package HP and Package type; user still needs to validate damage and body impulse/scatter.]

## Критерии готовности

- Generic hazard Entity создаётся без Package; Package — только event adapter.
- Самостоятельная ToxicArea наносит bounded periodic damage, Explosion один раз наносит radial damage и даёт физический импульс.
- Эффекты переживают удаление инициатора, если так определено lifetime policy; owner-attached hazard корректно реагирует на потерю owner.
- Общий Damage pipeline и source-side `C_NoDamage` не обходятся созданием эффекта; отдельного HP authority нет.
- Две разные посылки / бочки могут создать два эффекта без глобального cooldown. Токсичный клиент может иметь ту же самую зону, привязанную к себе, без копирования ToxicArea logic.
- Завершение R09 не требует реализации новых barrels/Customer gameplay, но их независимый factory fixture обязателен.

## Границы

Без сложной химической симуляции, готовой системы способностей, новых Customer/Barrel mechanics, второго generic damage pipeline и рефакторинга Grab/Cart/Motion. Сохранять GECS query/command boundaries, Godot physics authority, Godot 4.7/GDScript и read-only addons. Не запускать Godot/GUT после каждой мелкой правки: tests только после крупной задачи по правилам проекта.

## Первый шаг

Проверить R04/R08 по `task_history.md`, зафиксировать base и актуализировать `WORK.md`/`CURRENT_WORK.md` только при реальном старте реализации. Реализовать **R09.1 generic request/factory + independent prefab** отдельным коммитом, не добавляя в этот этап periodic damage и explosion resolution. Затем двигаться последовательно. Статус до начала реализации — planned.

## Handoff (2026-09-25)

Implementation and standalone non-Package fixture are ready. Final GUT coverage was reported passing by the user on 2026-09-25. Physics/visual acceptance remains open. Explosion impulse routing was corrected for controlled characters and free RigidBody3D, and parcel blast impulse was retuned for visible scatter; user validation is still required. The interaction HUD now exposes Player HP continuously and hovered Package authored type/hazard plus Package HP for that acceptance pass. Keep this task open until the user confirms ToxicArea damage and Explosion impulses/scatter. Durable contracts: `docs/hazards.md`; runner: `docs/smoke_runner.md`.
