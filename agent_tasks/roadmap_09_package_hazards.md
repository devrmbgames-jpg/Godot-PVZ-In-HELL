# R09 — Generic Toxic Area / Explosion и активация из Package

Status: planned
Зависимости: R04, R08
Ветка/base: зафиксировать при начале реализации.
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

Имена новых типов ниже — проектируемые, а не утверждение о существовании файлов. Не создавать параллельный RM09: канонический ID — R09.

## Архитектурный контракт

### 1. Источник и эффект независимы

- Trigger owner (Package/Barrel/Customer/Trap) публикует generic `HazardSpawnRequest`, а не инстанцирует напрямую токсичную зону или взрыв.
- `HazardSpawnRequest` содержит authored definition/PackedScene, world transform, устойчивый origin_id, необязательный origin/instigator и политику ownership/lifetime; фабрика/dispatcher создаёт отдельную Entity в World через безопасную GECS/SceneTree boundary.
- `O_PackageHazard` — только адаптер `PackageLifecycleEvent.EVENT` → `HazardSpawnRequest`. Он не вычисляет периодический урон, радиус взрыва или физические импульсы. В будущем barrel/customer adapters пользуются **тем же** generic request и фабрикой.
- Настройки эффекта должны быть `Resource`/Definition; не выбирать тип воздействия по `if source is E_Package` внутри generic Systems. Существующий `DEF_Package.hazard` можно использовать для определения authored эффекта/триггеров.
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

- [ ] Создать generic typed `HazardSpawnRequest`, authored hazard definitions/prefabs и единственный безопасный dispatcher/factory.
- [ ] Подготовить две независимые Entity/prefab с data-only компонентами и lifecycle/attribution.
- [ ] `O_PackageHazard` подписывается на `PackageLifecycleEvent.EVENT`; один выбранный `Leaking` или `Destroyed` запускает ToxicArea, `Destroyed` — Explosion. `Opened` — опциональный authored trigger, не универсальное правило.
- [ ] Повторные переходы `Leaking → Destroyed` не спавнят вторую зону для одноразовой Package. Несколько разных посылок дают независимые эффекты.
- [ ] Проверить, что прямой generic spawn без Package работает; запланировать подключение будущих Barrel/Customer через этот контракт.

### R09.2 — ToxicArea

- [ ] Система с конкретным GECS query по компоненту зоны; периодический tick с независимым состоянием каждой области и ограниченным временем жизни.
- [ ] Получатели выбираются spatial query/overlap; допускаются Player и будущие Customer с `C_Health` согласно authored eligibility.
- [ ] Урон идёт только через `DamageRequestService.submit()` с `DamageRequest.Type.TOXIC`. Учитывать source-side запрет и валидность target; один непрерывный overlap не превращается в бесконечный damage per frame.
- [ ] Независимый pool/зона сохраняется или очищается по собственному lifecycle; optional attached variant использует generic owner-follow, а не Package logic.

### R09.3 — Explosion

- [ ] Одноразовая atomic resolution через generic Explosion Entity/систему, независимо от класса инициатора.
- [ ] Spatial radius/затухание задаются ресурсом; установить явную LOS/obstacle policy (MVP: один raycast по цели; blocked полностью, без сложного частичного укрытия).
- [ ] Radial HP damage — только typed `DamageRequest.Type.EXPLOSION` через сервис. Физические тела получают `apply_central_impulse`/соответствующий Godot/Jolt impulse, включая тела без `C_Health`; не присваивать напрямую скорость.
- [ ] Идемпотентный single-shot, устойчивость к удалению origin/target, отсутствие self-recursion/непредусмотренного бесконечного взрывного цикла.
- [ ] Цепные реакции возможны через обычные typed damage/lifecycle события и отдельные one-shot guards; не кодировать Package-specific branch внутри Explosion.

### R09.4 — Lifecycle, регрессии и приёмка

- [ ] Очистка временных Hazard и cleanup world/physics references после окончания lifetime, disable либо удаления origin согласно выбранной policy.
- [ ] Data-driven persist flag и контракт будущего nightly reset (реальная R21 serialization вне R09).
- [ ] Readable MVP visualization для обеих самостоятельных Entity; gameplay authority не переносить в UI.
- [ ] Финальная GUT-проверка: независимый spawn без Package, one-shot активация, Leaking+Destroyed dedup, tick interval, радиус/LOS, удаление исходного объекта, cleanup, источник/instigator, запрет исходящего damage и несколько активных зон.
- [ ] Финальная physics/user-проверка: взрыв реально разбрасывает тела; ToxicArea наносит периодический урон; Barrel/Customer fixtures создают те же эффекты без второй реализации; существующий R08 Impact/Grab/Package pipeline не сломан.

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
