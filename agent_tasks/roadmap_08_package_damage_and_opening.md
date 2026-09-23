# R08 — Общий Impact Damage, повреждения и вскрытие Package

Status: implementation complete; awaiting user runtime acceptance
Зависимости: R02, R04, R05, R06.1
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 04](../docs/roadmap/04_morning_package_receiving.md), [R06.1](../docs/roadmap/06_1_interaction_hands_carry_push.md), [ТЗ 06](../docs/roadmap/06_package_damage_and_hazards.md), [ТЗ 16](../docs/roadmap/16_ui_and_feedback.md).

## Checkpoint 2026-09-24

- M1-4 preserved, including user O_Damage and C_Health.current migration.
- M5/M5.1 complete: central source veto, typed request path, independent contact capture/inbox and throw lifetime query. S_Damage was not restored.
- M6-9 implemented in separate commits: receiver profiles, protection, continuous Liquid tilt and explicit F/open.
- M10 code complete: read-only condition labels, existing damage smoke adapter, static review and manual handoff.
- Runtime/physics/visual tests were NOT RUN, as explicitly requested by the user. Original checklists below remain acceptance criteria, not claims of test success.
- [Manual checks](../docs/r08_manual_validation.md); [durable contract](../docs/damage_impact.md).
- Next: user playtest; after acceptance update task_history.md, remove this task and return trackers to idle.

## Цель

Расширить существующий общий damage pipeline универсальным physical impact damage и затем использовать его для Package.

Ключевой контракт:

```text
C_Health
    = Entity вообще может получать HP damage

C_ImpactReceiver + C_Health
    = Entity может получать damage от физических столкновений

C_ThrowDamage
    = source может добавить специальный бонус к валидному thrown-impact

C_NoDamage
    = source-side hard veto; Entity не может наносить damage другим
```

Package не должна иметь отдельную параллельную формулу HP/impact. Она использует общий `C_Health`, generic impact pipeline и собственные lifecycle reactions `Damaged/Destroyed/Opened/Leaking`.

## Начать здесь

- [o_damage.gd](../content/observers/gameplay/o_damage.gd)
- [c_health.gd](../content/components/gameplay/c_health.gd)
- [damage_request.gd](../content/contracts/damage/damage_request.gd)
- [e_grabbable_body.gd](../content/entities/props/e_grabbable_body.gd)
- [e_package.gd](../content/entities/packages/e_package.gd)
- [def_package.gd](../content/definitions/gameplay/packages/def_package.gd)
- [c_package_state.gd](../content/components/gameplay/c_package_state.gd)

Не начинать с Bubble Wrap/Liquid/Opening. Сначала завершить generic Health + Impact foundation и зафиксировать его отдельным milestone commit.

> **НЕМЕДЛЕННЫЙ ARCHITECTURE GATE ДЛЯ R08**
>
> Damage/Impact pipeline уже активно меняется в R08, поэтому найденные GECS-проблемы `S_Damage` и `S_Impact` **не откладывать до R22.5**.
> После завершения source-side `C_NoDamage` (Milestone 5) немедленно выполнить Milestone 5.1 ниже и только затем переходить к Package-specific Milestone 6–9.
>
> Разрешённый scope сейчас: `S_Damage`, `S_Impact`, их typed contracts/components/physics bridge и минимальные нейтральные helpers/observers, необходимые для устранения их прямых System-зависимостей.
> Не использовать этот gate как повод раньше времени рефакторить Grab/Push/Cart/Input целиком; их широкий polish остаётся R22.5.


---

## Milestone 1 — Унифицировать Health

- [ ] Перевести Package с `C_PackageIntegrity` на общий `C_Health`.
- [ ] Убедиться, что любой Entity с `C_Health` может быть target обычного `DamageRequest`.
- [ ] Удалить/свернуть package-specific HP branch из `S_Damage`; общий System не должен выбирать отдельную формулу по типу Entity.
- [ ] Разделить generic Health depletion и entity-specific lifecycle reaction.
- [ ] Character defeat cleanup не должен автоматически применяться к Package/props только потому, что Health достиг нуля.
- [ ] Package-owned Observer/System обновляет `C_PackageState.Damage` по результату общего damage pipeline: первый applied damage → `DAMAGED`, zero Health → `DESTROYED`.
- [ ] Сохранить idempotent zero-health handling: destruction/defeat effect выполняется ровно один раз.

### Готовность milestone

- Player и Package получают один и тот же generic `DamageRequest`;
- обе цели используют `C_Health`;
- Package больше не нуждается в отдельном количественном HP authority;
- zero-health Player и zero-health Package запускают разные lifecycle reactions без special-case HP arithmetic в `S_Damage`.

---

## Milestone 1.1 — Post-Health-Depletion lifecycle

Переход `C_Health.value > 0 -> 0` является отдельным gameplay-событием и должен commit-иться ровно один раз.

### Общий contract

- [ ] Сделать generic outcome/event для исчерпания Health. Предпочтительное имя результата: `HEALTH_DEPLETED` вместо character-specific `DEFEATED`.
- [ ] `S_Damage` отвечает только за изменение `C_Health` и публикацию typed result/event; он не решает, как конкретный Entity умирает, ломается или удаляется.
- [ ] Повторный damage по Entity с уже нулевым Health не должен повторно запускать depletion lifecycle.
- [ ] Depletion event должен сохранять target, source, damage type, последний applied amount и исходный `DamageRequest`, чтобы downstream systems могли атрибутировать смерть/разрушение.
- [ ] Удаление/замена Entity во время downstream reaction не должно приводить к повторному execution того же depletion event.

### Living Entity

- [ ] Для живых Entity depletion reaction добавляет marker/state `C_Death` либо эквивалентный typed death-state.
- [ ] `C_Death` не является заменой `C_Health`; это lifecycle state после исчерпания Health.
- [ ] Добавление `C_Death` идемпотентно.
- [ ] Character-owned death observer/system затем отвечает за control/AI disable, release/drop held objects, animation/ragdoll/corpse cleanup.
- [ ] R08 создаёт только общий contract/минимальную заглушку death-state; полноценные Customer/combat death reactions остаются R17.

### Package

- [ ] Package **не получает `C_Death`**.
- [ ] Package depletion reaction переводит `C_PackageState.Damage -> DESTROYED` ровно один раз.
- [ ] `DESTROYED` не означает немедленный `queue_free()`/удаление Entity.
- [ ] Разрушенная Package остаётся доступной для downstream lifecycle: debris, содержимое, Hazard, Terminal/Customer consequences, persistence/cleanup.
- [ ] Package удаляется из ECS/world только отдельным lifecycle/cleanup решением после того, как обязательные post-destruction reactions завершены.

### Generic post-depletion spawn/effect hook

R08 должен подготовить **data-driven заглушку**, пригодную не только для Package.

Предусмотреть optional authored component/definition с семантикой уровня `HealthDepletionEffects` / `OnHealthDepletedSpawn` (точное имя выбрать при реализации по project naming rules).

Минимальный contract заглушки:

- [ ] список gameplay spawn entries после Health depletion;
- [ ] отдельные optional presentation hooks для VFX/SFX;
- [ ] spawn выполняется только один раз на один committed depletion;
- [ ] отсутствие компонента означает «ничего дополнительно не спавнить»;
- [ ] generic handler не проверяет конкретный класс Entity;
- [ ] spawn entries могут ссылаться на authored `PackedScene`/definition, но не содержат runtime Node ownership;
- [ ] downstream-specific события (например Package Hazard) могут быть отдельным typed hook и не обязаны маскироваться обычным debris spawn.

Для R08 достаточно реализовать API/placeholder и один простой test fixture. Полный набор мусора, gore, corpse assets, loot и VFX контента **не входит** в R08.

### Package destruction stub

Для Package предусмотреть минимум такие будущие реакции:

```text
Package Health -> 0
    ↓
HEALTH_DEPLETED
    ↓
C_PackageState.DESTROYED
    ↓
post-depletion dispatcher
    ├─ debris spawn placeholder
    ├─ content/drop spawn placeholder
    ├─ VFX/SFX placeholder
    └─ typed Hazard activation hook -> R09
```

На этапе R08 допускается placeholder scene/resource вместо финального мусора, но сам lifecycle и single-fire semantics должны быть рабочими.

### Ownership / cleanup rules

- [ ] Post-depletion spawn не должен выполняться из UI.
- [ ] Не вызывать spawn непосредственно внутри арифметики `S_Damage`.
- [ ] Если target был held/pushed/targeted, соответствующий domain observer безопасно освобождает relationships/control до удаления физического Entity.
- [ ] Если destroyed Entity должен остаться физическим wreck/corpse, depletion не должен автоматически удалять его.
- [ ] Если конкретный type должен исчезнуть после spawn, удаление выполняется только после commit всех обязательных spawn/hooks.
- [ ] Spawned debris не наследует автоматически source `C_ThrowDamage`/combat attribution исходного Entity, если это явно не задано data.

### Готовность milestone

- `C_Health` пересекает zero один раз → один typed depletion event;
- living fixture получает `C_Death`;
- Package fixture получает `DESTROYED`, но остаётся Entity до отдельного cleanup;
- generic spawn stub создаёт один placeholder debris/effect entry;
- повторный damage после zero не создаёт второй debris/death/hazard hook.

---

## Milestone 2 — Generic physical Impact contract

- [ ] Создать typed runtime contract физического contact/impact; точное имя выбрать по текущим naming rules, но он не должен называться Package-specific.
- [ ] Создать `C_ImpactReceiver`.
- [ ] `C_ImpactReceiver` работает только вместе с `C_Health`; без Health collision damage не применяется.
- [ ] Передавать contact data из тонкого Entity/physics bridge в owning System/service; Entity script не уменьшает Health напрямую.
- [ ] Обрабатывать столкновение как два независимых направления `A -> B` и `B -> A`.
- [ ] Для каждого направления source/receiver определяются явно.
- [ ] Рассчитывать базовый physical impact damage минимум из:
  - source mass;
  - relative velocity по нормали collision;
  - фактической силы/impulse contact.
- [ ] Не использовать только `linear_velocity.length()` как критерий силы удара.
- [ ] Сделать коэффициенты/thresholds data-driven; никаких magic damage values в Entity/System logic.
- [ ] Классифицировать итоговый impact как `NONE / WEAK / MEDIUM / STRONG` для tuning/feedback, но severity не заменяет количественный damage.
- [ ] После расчёта создавать обычный `DamageRequest` с `DamageRequest.Type.IMPACT`.

### Обязательные физические инварианты

- лёгкий предмет наносит существенно меньше damage тяжёлого при сопоставимом collision;
- низкая relative speed не создаёт огромный damage только из-за массы;
- тяжёлый быстрый объект может причинить высокий damage;
- resting contact и скольжение не считаются повторяющимся сильным ударом;
- damage не зависит от FPS;
- маленькая зажигалка без специальных компонентов не может снести машину только из-за collision callback.

---

## Milestone 3 — Contact deduplication

- [ ] Один продолжающийся contact не должен создавать damage каждый physics frame.
- [ ] Выбрать явный owner состояния dedup: contact-pair state, impact token, separation state или эквивалентный typed contract.
- [ ] Новый сильный удар после реального separation/re-impact снова разрешён.
- [ ] Удаление одного Entity безопасно очищает contact state.
- [ ] Не использовать глобальный произвольный cooldown, который блокирует независимые столкновения разных объектов.

### Готовность milestone

Сценарий:

```text
box falls on floor
-> one impact

box rests on floor for 5 sec
-> no repeated damage

box is lifted and dropped again
-> new impact
```

---

## Milestone 4 — C_ThrowDamage

- [ ] Добавить optional source component `C_ThrowDamage`.
- [ ] Компонент содержит data-driven `throw_damage` либо typed throw damage profile.
- [ ] `C_ThrowDamage` **не заменяет** базовый physical impact calculation.
- [ ] Итог валидного thrown-impact = physical base damage + permitted throw bonus.
- [ ] Бонус применяется только при активном/валидном throw context.
- [ ] Обычное падение, толкание, resting contact или случайный удар предмета не получают throw bonus.
- [ ] Throw context имеет ограниченный lifecycle и снимается после первого валидного hit, истечения окна либо другого явно выбранного termination condition.
- [ ] Один бросок не может начислить throw bonus много раз из-за нескольких contact frames.
- [ ] Source identity сохраняет фактический damaging Entity; бросивший actor может храниться отдельно как attribution/instigator, если это потребуется будущему combat/reputation.

### Примеры

```text
lighter, no C_ThrowDamage
-> physics-only impact

knife + C_ThrowDamage, falls from table
-> physics-only impact

knife + C_ThrowDamage, thrown by Player
-> physics impact + throw bonus
```

---

## Milestone 5 — C_NoDamage

- [ ] Добавить optional marker/component `C_NoDamage`.
- [ ] Его семантика строго source-side: Entity может получать damage, но не может наносить damage другим.
- [ ] Если source имеет `C_NoDamage`, outgoing `DamageRequest` от этого source не должен применяться.
- [ ] `C_NoDamage` имеет приоритет над `C_ThrowDamage`.
- [ ] Проверка должна быть гарантирована общим damage contract, а не продублирована во всех producer Systems.
- [ ] В `DamageRequest.source` указывать фактический damaging Entity, иначе veto теряет однозначность.
- [ ] Environment/null source обрабатывается отдельно и не должен случайно считаться Entity с `C_NoDamage`.

### Пример

```text
training prop:
C_Health
C_ImpactReceiver
C_NoDamage

может сам получить impact damage
может физически толкать Player
не наносит Player HP damage
```

---

## Milestone 5.1 — НЕМЕДЛЕННО: GECS cleanup S_Damage + S_Impact

**Порядок:** выполнить сразу после Milestone 5 и **до Milestone 6**. Это часть R08, а не R22.5.

### S_Damage — исправить сейчас

- [ ] Удалить прямую зависимость `S_Damage -> S_Grab`. Проверка доступности target/source не должна обращаться к чужому System как к helper/service.
- [ ] Удалить service-locator pattern из `S_Damage.submit()`: не сканировать `ECS.world.systems` в поисках экземпляра `S_Damage`.
- [ ] Завести явный typed request/inbox/event путь для `DamageRequest`, совместимый с текущим GECS scheduling.
- [ ] `S_Damage` оставить единственным authority **только для Health arithmetic + DamageResult publication**.
- [ ] Source-side veto `C_NoDamage`, validation request и Health mutation должны находиться в общем damage contract, а не дублироваться по producer Systems.
- [ ] Не помещать в `S_Damage` Package/Living-specific lifecycle, debris, death, presentation или impact calculation.
- [ ] Если queue/inbox требует отдельного Component/contract/service, он должен быть typed и не превращаться во второй damage authority.

### S_Impact — исправить сейчас

- [ ] Удалить прямую зависимость `S_Impact -> S_Damage`; impact producer отправляет обычный typed `DamageRequest` через новый общий damage request path.
- [ ] Удалить прямую зависимость `S_Impact -> S_Grab`; held/availability semantics читать через authoritative Components/Relationships либо нейтральный non-System helper.
- [ ] Разделить physics callback capture и scheduled impact resolution:
  - physics bridge/solver только снимает typed contact snapshot;
  - GECS System/sub-system обрабатывает pending contacts, dedup и impact resolution.
- [ ] Не использовать `S_Impact` как static service namespace, если часть кода не является GECS-scheduled work.
- [ ] Throw-window lifetime перевести на явный query по `C_ThrowDamage` с `iterate()`, а не на broad/manual world scan.
- [ ] Contact-pair dedup ownership оставить однозначным и независимым от presentation/Grab implementation.
- [ ] Structural mutations во время GECS iteration выполнять через `cmd`/разрешённый deferred lifecycle.
- [ ] Сохранить уже реализованные R08 semantics: directional impact, pair rearm after separation, throw one-hit/timeout/pickup termination, instigator/source attribution.

### Boundary / non-goals этого gate

- [ ] Не рефакторить сейчас весь `S_Grab`; допускается только вынести минимальный neutral helper/relationship query, необходимый для устранения `S_Damage/S_Impact -> S_Grab`.
- [ ] Не менять формулу impact damage, thresholds, severity или balance без отдельной причины из R08.
- [ ] Не менять Push/Cart/Motion/Input архитектуру в этом milestone.
- [ ] Не создавать второй damage pipeline для Package, Combat или Hazard.
- [ ] Не переносить gameplay authority в Entity callback или UI.

### Готовность Milestone 5.1

До перехода к Milestone 6 должны выполняться все условия:

- `S_Damage` не вызывает другие `S_*` как service/helper;
- `S_Damage` не ищет себя через `ECS.world.systems`;
- `S_Impact` не вызывает `S_Damage` и `S_Grab`;
- contact capture отделён от scheduled impact resolution;
- `C_ThrowDamage` lifetime имеет специфичный GECS query + `iterate()`;
- все impact producers используют один typed `DamageRequest` path;
- текущие Health/depletion, contact dedup и throw semantics сохранены;
- после этого R22.5 рассматривает Damage/Impact только как regression audit, а не как отложенный основной рефакторинг.

---

## Milestone 6 — Package impact rules

- [ ] Package использует `C_Health + C_ImpactReceiver`.
- [ ] Fragile выражать через data-driven impact tolerance/resistance/profile, а не через hard-coded `if Package.FRAGILE` в generic impact System.
- [ ] Heavy должен влиять на outgoing impact прежде всего через реальную массу; не добавлять отдельный magic bonus, если масса уже выражает поведение.
- [ ] `C_PackageState.Damage` остаётся lifecycle/presentation state, а не HP authority.
- [ ] Первый applied damage переводит `UNDAMAGED -> DAMAGED`.
- [ ] Health == 0 переводит `DAMAGED/UNDAMAGED -> DESTROYED` ровно один раз.
- [ ] Package destruction предоставляет typed hook будущему Hazard R09.

---

## Milestone 7 — Bubble Wrap protection state

- [ ] Добавить package protection state/modifier с tier.
- [ ] Protection применяется на receiver-side внутри generic impact resolution до создания/применения HP damage.
- [ ] Impact severity до поддерживаемого tier включительно полностью блокируется.
- [ ] Более сильный impact проходит обычный pipeline.
- [ ] Bubble Wrap не блокирует произвольные non-impact damage types без отдельного data rule.
- [ ] R08 реализует только protection state/semantics.
- [ ] Inventory item и одно-кликовое применение Bubble Wrap остаются R19.

---

## Milestone 8 — Liquid tilt

- [ ] Для Liquid учитывать отклонение от вертикали.
- [ ] Использовать data-driven допустимый угол и duration.
- [ ] Явно выбрать continuous либо accumulated time semantics и покрыть тестами.
- [ ] Нормальное краткое покачивание не должно повреждать Package.
- [ ] По достижении условия обновить Package state `Damaged/Leaking`.
- [ ] Если tilt должен уменьшать Health, он создаёт обычный typed `DamageRequest`, но не маскируется под collision impact.
- [ ] Hazard trigger остаётся typed hook для R09.

---

## Milestone 9 — Package Opening

- [ ] Добавить осознанное действие открытия **любой физически доступной Package** через общий interaction contract.
- [ ] Не блокировать действие из-за ownership/recipient: Player вправе нарушить правила.
- [ ] Opening не является damage по умолчанию; это отдельный Package state/event.
- [ ] Повторное открытие не создаёт duplicate side effects.
- [ ] State `Opened` сохраняется до фактического завершения Package lifecycle.
- [ ] Предоставить typed hook R09/R11 для hazard/customer consequences.

---

> **R08 ordering invariant:** Milestone 6–9 запрещено считать начатыми/готовыми, пока Milestone 5.1 Damage/Impact architecture gate не завершён.

## Milestone 10 — Feedback / regression

- [ ] Показать минимально читаемое Package `Damaged/Destroyed/Opened` состояние без переноса authority в UI.
- [ ] Проверить взаимодействие impact с Carry/hand/throw.
- [ ] Проверить, что held object не наносит holder damage до валидного release/throw contract.
- [ ] Проверить несколько одновременно сталкивающихся Entity без глобального cooldown.
- [ ] Проверить cleanup после удаления source/target.
- [ ] Проверить существующие damage, grab, receiving, scanner и marker regressions.

---

## Критерии готовности R08

- Любой Entity с `C_Health` принимает обычный damage.
- Collision damage получает только Entity с `C_Health + C_ImpactReceiver`.
- Player, будущий Customer, Package и destructible props используют один generic impact algorithm.
- Базовый impact учитывает source mass, relative collision speed и contact impulse/force.
- Лёгкий обычный предмет не способен нанести нереалистичный огромный damage тяжёлому target.
- `C_ThrowDamage` добавляет урон только валидному thrown-impact.
- `C_NoDamage` строго запрещает outgoing damage данного Entity и перекрывает `C_ThrowDamage`.
- Один contact не наносит damage каждый frame.
- Package использует `C_Health`, а `Damaged/Destroyed` являются package lifecycle state.
- Переход Health через zero публикует один generic post-depletion event; living Entity получает death-state, Package — `DESTROYED` без автоматического удаления.
- Data-driven post-depletion spawn/effect stub способен однократно породить placeholder debris/effect и предоставляет hook для будущих Package contents/Hazard.
- Fragile/Bubble Wrap не требуют отдельной package-only формулы impact damage.
- Liquid и Opening имеют отдельные semantics и не ломают generic collision pipeline.
- R17 сможет использовать готовый R08 impact foundation без второго impact System/formula.

## Проверки

GUT:
- generic Health damage;
- target без Health;
- target с Health без `C_ImpactReceiver`;
- target с Health + `C_ImpactReceiver`;
- directional A→B / B→A;
- mass/speed/impulse boundaries;
- `C_NoDamage`;
- `C_ThrowDamage` normal fall vs valid throw;
- contact dedup/re-impact;
- Health depletion single-fire + `C_Death` living fixture;
- Package Damaged/Destroyed без автоматического удаления;
- post-depletion spawn stub single-fire;
- Fragile/protection tiers;
- Liquid duration;
- Opening idempotency.

Physics integration:
- лёгкий предмет → тяжёлый target;
- тяжёлый предмет → damageable target;
- Player fall/impact;
- Package drop;
- thrown sharp object;
- resting contact;
- separation + second impact.

Общие команды и правила завершения — в [README](README.md).

## Границы

- R08 создаёт generic impact foundation, но не полноценный combat/weapon framework.
- R17 отвечает за melee, aggressive Customer и combat attribution/reputation, переиспользуя R08 impact.
- R09 реализует ToxicLeak/Explosion поверх общего damage contract.
- R19 реализует Inventory/Consumable Bubble Wrap.
- Деньги/штрафы не применяются непосредственно в момент damage.
- Не создавать второй parallel damage pipeline.
- Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons.

## Первый шаг

1. Явно поставить текущую предыдущую активную задачу на паузу/завершить её checkpoint, чтобы `WORK.md/CURRENT_WORK.md` не вели агента в другой feature.
2. Проверить завершение R02/R04/R05/R06.1 по `task_history.md`.
3. Обновить `WORK.md/CURRENT_WORK.md` на **R08 / Milestone 1 — Generic Health unification**.
4. Реализовать и проверить только Milestone 1.
5. Создать локальный commit.
6. Только затем переходить к generic impact physics.
