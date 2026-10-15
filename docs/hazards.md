# Автономные опасные эффекты (R09)

`ToxicArea` и `Explosion` — отдельные Entity. Посылка, бочка, клиент или ловушка только инициируют появление эффекта; урон и время жизни принадлежат самому эффекту. Единственный обработчик HP — `O_Damage`.

## Подключение к новому объекту

1. Объект должен быть GECS Entity на пространственном узле, зарегистрированном в World.
2. Добавить в `component_resources` компонент `C_HazardEmitter`.
3. Назначить `hazard_scene`: автономную сцену эффекта (`explosion.tscn`, `toxic_area.tscn` или другую `E_Hazard`). Сама сцена содержит свой `DEF_Hazard` с радиусом, уроном, lifetime и прочими параметрами.
4. Для автоматического срабатывания при исчерпании HP добавить `C_Health`. Для ручной активации вызвать `HazardEmitter.activate(owner, instigator)`.

`one_shot = true` защищает инициатора от повторного запуска. У повторяемого инициатора каждый запуск увеличивает `sequence`. Фабрика дополнительно запоминает `request_id` на время существования World: повторная доставка того же запроса не создаёт второй эффект, даже после его удаления/reset. Разные объекты не делят cooldown.

Главная сцена уже регистрирует необходимые обработчики. В другой сцене нужны `O_HazardSpawn`, `O_HazardEmitter`, `O_ToxicAreaSetup`, `O_ExplosionSetup`, `O_HazardReset`, `O_Damage` и системы `S_HazardFollow`, `S_ToxicArea`, `S_Explosion`, `S_HazardLifetime`. Системы обрабатываются в группе `GamePlay` на физическом callback, с обычным GECS flush после каждой системы. Их delta — секунды шага `GameTime`, а не native physics delta. `deps()` ставит следование до воздействия, а удаление — после него.

## Прямой запрос без объекта-инициатора

```gdscript
var request: HazardSpawnRequest = HazardSpawnRequest.new()
request.request_id = "trap-17:activation-3"
request.origin_id = "trap-17"
request.scene = preload("res://content/domains/hazards/entities/explosion.tscn")
request.world_pose = Transform3D(Basis.IDENTITY, Vector3(2, 1, 3))
HazardSpawnService.submit(request)
```

`submit()` возвращает принятие запроса на канал событий. Обязательны непустые `request_id`/`origin_id`, scene и конечная world_pose; профиль и prefab окончательно проверяет фабрика/setup. Факт регистрации публикуется как `HazardSpawnResult.EVENT`, после него профильная настройка ещё может удалить некорректный эффект. Prefab должен иметь нефизический `E_Hazard`/Node3D-корень. Его exported `definition` содержит immutable tuning/lifetime/ownership; необязательный `request.definition` заменяет этот профиль целиком. `origin` и `instigator` необязательны. Для атрибуции, переживающей удаление объектов, служат `origin_id` и `instigator_id`. Журнал O_HazardSpawn потребляет ID до попытки создания: отказ фабрики не разрешает повтор с тем же ID. Такой отказ записывается в BoundaryTrace и не откатывает уже принятый emitter fired/sequence.

## Поведение

| Эффект | Контракт |
| --- | --- |
| ToxicArea | `Area3D`: сфера при `floor_height = 0`, тонкий цилиндр при положительной высоте. Собственный таймер; первый урон через полный `tick_seconds`, пропущенные интервалы объединяются в один запрос на получателя. По умолчанию нужны `C_Health` + `C_Living`; `living_only = false` допускает остальные объекты с HP. |
| Explosion | Один расчёт на физическом шаге. Вес: `(1 - distance / radius) ^ falloff_power`, обрезанный по радиусу. Расстояние берётся до центра ближайшей физической формы цели. Один raycast на Entity/самостоятельное тело; препятствие полностью блокирует HP и импульс. По умолчанию препятствия — только `Environment` (layer 1). Динамические физические props должны находиться на `Props` (layer 4), а не на Environment. |
| Импульс | Управляемый персонаж получает blast через `C_Motion.pending_impulse`; обычный `RigidBody3D` пробуждается и получает `apply_central_impulse`, без присваивания скорости. `upward_bias` добавляет вертикальную составляющую до нормализации. Замороженные тела не толкаются. |

`maximum_targets` ограничивает число результатов физического запроса взрыва (включая формы и препятствия). В плотных сценах его нужно увеличить. Коллайдеры живого инициатора исключаются из LOS, чтобы корпус не перекрывал собственный взрыв. Частичное укрытие и расчёт по поверхности крупных тел в MVP отсутствуют. Перекрытия Area3D обновляются физическим движком, поэтому перемещённая привязанная зона использует результаты последнего физического шага.

Огненное присутствие NPC использует два отдельных эффекта: прежнюю сферу у тела и
`npc_floor_fire.tscn` с `def_npc_floor_fire.tres` (радиус 10 м, высота 0,2 м).
`DEF_NpcFireAura` хранит immutable профили; `NpcTraitService.ensure_aura()` создаёт каждый
отсутствующий профиль один раз через общую фабрику и проверяет владельца после spawn fact.
Следование/TTL/урон принадлежат обычным Hazard Systems. Напольный центр находится на половине
высоты над корнем NPC; реальные физические перекрытия позволяют уйти от огня, поднявшись выше
пола. Риск маршрута, непосредственная опасность и блокировка сна учитывают ограничение по
высоте; прежняя оценка сфер сохранена. Fire immunity проходит через общий resistance owner.
Fire parcel ignition uses `def_npc_opening_fire_blast.tres` (FIRE damage, radius 3 m, lifetime 0.75 s). Customers commits one roll from a real eligible physical content fact; generic Explosion/HP/impulse owners execute it. See [Fire receiver opening](customers.md#fire-receiver-opening).

Урон всегда имеет `source = hazard Entity`; живой `instigator` и стабильные идентификаторы передаются отдельно. `C_NoDamage` инициатора копируется на эффект при создании и продолжает блокировать HP после удаления инициатора. Он не отменяет физический импульс — это действующий контракт запрета исходящего урона. Цепные реакции проходят через обычный damage/depletion и отдельный one-shot каждого следующего инициатора.

## Посылки

`DEF_Package` не содержит enum/type Hazard. `hazard_on_damaged` создаётся от самой Package на первом переходе в `DAMAGED`; стабильный request-id не позволяет короткому эффекту стакаться. При разрушении `O_PackageDestruction` создаёт scene-local debris из `C_PackageDestruction`, переносит в него `C_PackageDebris(package_id, DEF_Package)` и удаляет исходную Package. Затем `PackageDebrisSpawnedEvent` позволяет `O_PackageDestroyedHazard` запустить `hazard_on_destroyed` уже от debris. Independent Explosion только стартует с его позиции; `FollowOrigin + Despawn` ToxicResidue следует за debris и удаляется вместе с ним. Текущий long residue живёт 900 секунд (15 минут).

## Время жизни, следование и будущий reset

- `Independent`: эффект остаётся в мире после удаления инициатора.
- `FollowOrigin`: native GECS Relationship effect → owner с payload `R_HazardFollow` перемещает только нефизический корень эффекта. При потере/отключении владельца `Detach` оставляет эффект на последней позиции, `Despawn` удаляет его. Long ToxicResidue уничтоженной посылки использует `Despawn` и debris как owner. Отключённый source сохраняет listener потери связи; pending retirement не попадает в Night snapshot. Restore перепривязывает связь без повторения owner-loss effects; формат сохранённых target/offset/policy не меняется.
- Истечение TTL или отключение самого эффекта удаляет регистрацию и узлы; удаление через `World.remove_entity()` также освобождает сцену. У взрыва отсчёт TTL начинается с разрешения, чтобы короткий цепной эффект не исчез до первого хода своей системы.
- `persistent` исключает эффект из обычного reset, но не отменяет TTL.

Для явного сброса сценарий может отправить:

```gdscript
var reset: HazardResetRequest = HazardResetRequest.new()
ECS.world.emit_event(HazardResetRequest.EVENT, null, reset)
```

`include_persistent = true` удаляет все эффекты. Текущий `NightResetService` отдельно удаляет непостоянные опасности и применяет owner-loss policy к оставшимся. Closed persistence сохраняет поддерживаемые persistent hazards: остаток TTL, часы токсина, resolved, стабильные ID/атрибуцию, follow-policy и producer `fired`/`sequence`. `PersistentHazardState` восстанавливает связи и геометрию без повторного взрыва. Журнал попыток O_HazardSpawn остаётся в памяти экземпляра Observer; это не сохраняемый журнал. Общий контракт Night/save — в [persistence.md](persistence.md).

## Проверка пользователем

```powershell
.\utils\run_smoke.ps1 -Name hazards
```

`hazards_smoke.tscn` создаёт отдельный World: взрывные объекты без `C_Package`, привязанный эффект условного клиента, несколько зон, получателей с/без HP и стену. Проверяет дедупликацию, интервал, eligibility, удаление инициатора, follow-policy, reset, цепную реакцию, LOS, затухание, импульс и запрет исходящего урона. Небольшой отдельный фрагмент проверяет адаптер `Leaking → Destroyed`.

Команда выше — инструкция запуска smoke, а не свидетельство его прохождения. Релевантные non-visual Godot/GUT/validator проверки агент запускает по AGENTS.md; gameplay/визуальная приёмка требует разрешения пользователя. Простые зелёная зона и оранжевая вспышка показывают радиус; их читаемость и силу разбрасывания нужно оценить в игре. Инструкция запуска и расположение журналов: [smoke_runner.md](smoke_runner.md).
