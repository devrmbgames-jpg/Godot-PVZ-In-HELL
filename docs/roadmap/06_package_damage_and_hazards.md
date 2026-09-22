# ТЗ 06 — Повреждение посылок, физический Impact и опасное содержимое

> **Implementation coverage:** generic Health/Impact foundation + Package damage/opening **R08**, hazards **R09**, Bubble Wrap consumable application **R19**, final feedback **R22**.

## Цель

Сделать физические столкновения частью общего damage pipeline и поверх него реализовать значимое обращение с Package.

R08 не создаёт отдельную «систему урона коробок». Она расширяет общий damage contract так, чтобы Player, Customer, Package, разрушаемая мебель и будущие Entity использовали одни и те же базовые правила.

---

## Универсальный Health contract

`C_Health` — единственный количественный authority того, сколько damage способен выдержать Entity.

Правила:

- любой Entity с `C_Health` может быть target обычного `DamageRequest`;
- Entity без `C_Health` не получает HP damage;
- Package должна перейти с отдельного `C_PackageIntegrity` на общий `C_Health`;
- `S_Damage` не должен иметь отдельную ветку вычисления HP специально для Package;
- Player, Customer, Package и destructible world-object проходят через один общий Health resolution;
- entity-specific последствия нулевого Health не принадлежат общей формуле damage.

Последний пункт обязателен. Ноль Health означает общий факт «ресурс исчерпан», но реакция зависит от Entity:

- Player/Customer → defeat/death lifecycle;
- Package → `Destroyed`, cleanup marking и возможная активация Hazard;
- destructible prop → собственный destruction/break lifecycle.

Не помещать character-specific cleanup или Package-specific state transitions внутрь общей формулы вычитания Health, если это можно обработать Observer/System владельца соответствующего lifecycle.

---

## Получение урона от столкновений

Обычного `C_Health` недостаточно, чтобы любое случайное соприкосновение автоматически наносило damage.

Для collision/impact damage target должен иметь:

- `C_Health`;
- `C_ImpactReceiver`.

### C_ImpactReceiver

`C_ImpactReceiver` означает: Entity разрешено получать damage от физических столкновений.

Компонент должен быть data-driven и может хранить либо ссылаться на настройки impact resistance/thresholds/multipliers.

Минимальный контракт:

- без `C_ImpactReceiver` физический contact не создаёт impact damage этому Entity;
- наличие `C_ImpactReceiver` без `C_Health` не делает Entity damageable;
- impact tuning не должен требовать проверки конкретного класса `Package`, `Player` или `Customer`;
- Fragile/Bubble Wrap и другие особенности должны изменять данные/модификаторы impact receiver, а не создавать отдельную формулу в `S_Damage`.

---

## Источник физического Impact

Физический contact рассматривается как взаимодействие двух тел.

Если столкнулись A и B, система независимо рассматривает два направления:

```text
A -> B
B -> A
```

Damage в направлении `A -> B` возможен только если:

1. B имеет `C_Health`;
2. B имеет `C_ImpactReceiver`;
3. A не запрещено быть источником damage;
4. contact является достаточно сильным по физической модели;
5. это не повторное начисление одного продолжающегося контакта.

Это позволяет, например, тяжёлой машине разрушить маленький предмет, но не позволяет маленькой зажигалке снести машину только потому, что collision event существует.

---

## Базовый физический Impact Damage

Если source не имеет специального throw-bonus, impact damage вычисляется из реальной физики столкновения.

В расчёте должны участвовать как минимум:

- масса source-body;
- относительная скорость тел в направлении столкновения;
- сила/импульс фактического contact.

Точная формула и коэффициенты должны быть data-driven и проверяться тестами. Не использовать один только `linear_velocity.length()`: боковое скольжение/совместное движение не должно считаться сильным лобовым ударом.

Базовая модель обязана соблюдать следующие инварианты:

- маленькая масса при той же скорости наносит существенно меньше damage, чем большая;
- маленькая относительная скорость не создаёт большой damage только из-за большой массы;
- слабое касание/покой на поверхности не наносит повторяющийся damage;
- сильный удар тяжёлого объекта способен причинить высокий damage;
- расчёт не зависит от frame rate;
- один и тот же contact не наносит damage каждый physics frame.

Не вводить magic damage values в Entity scripts. Настройки impact curve/thresholds/resistance должны находиться в Component/Definition data.

---

## C_ThrowDamage

Некоторые физические предметы опаснее обычного тела именно при намеренном броске: нож, ножницы, острый инструмент и подобные предметы.

Для них используется optional `C_ThrowDamage`.

`C_ThrowDamage` — **source-side** компонент. Он не делает объект damageable и не заменяет физический base damage.

Минимальный contract:

- компонент содержит data-driven дополнительный `throw_damage` либо эквивалентный throw damage profile;
- бонус применяется **только к валидному thrown-impact**;
- обычное падение, покой, толчок или случайное столкновение того же предмета не получают throw bonus;
- базовый физический damage всё равно вычисляется из mass/speed/contact impulse;
- итоговый thrown impact использует базовый physical damage + разрешённый throw bonus;
- throw context должен иметь ограниченное lifecycle и не оставаться активным после первого валидного попадания/истечения окна/потери условий броска;
- один throw не должен многократно добавлять `throw_damage` из-за нескольких physics frames одного контакта.

Пример:

```text
зажигалка без C_ThrowDamage
    -> только physics impact по массе/скорости/импульсу

нож с C_ThrowDamage, просто упал со стола
    -> только physics impact

нож с C_ThrowDamage, валидно брошен Player
    -> physics impact + throw bonus
```

---

## C_NoDamage

`C_NoDamage` — optional **source-side hard veto**.

Entity с `C_NoDamage`:

- может иметь собственный `C_Health`;
- может иметь `C_ImpactReceiver` и получать damage;
- может физически толкать/сталкиваться с другими телами;
- **не может быть источником DamageRequest для другого Entity**, пока компонент активен.

Если source имеет одновременно `C_NoDamage` и `C_ThrowDamage`, побеждает `C_NoDamage`: outgoing damage равен нулю и DamageRequest не создаётся.

Проверка должна быть централизованной/гарантированной общим damage contract, а не зависеть от того, вспомнил ли конкретный producer проверить marker.

В `DamageRequest.source` должен указываться фактический damaging Entity. Это необходимо, чтобы `C_NoDamage` имел однозначную семантику.

---

## Impact event / processing boundary

Godot/Jolt contact data поступает из тонкого physics bridge, но gameplay damage рассчитывается owning System/service.

Рекомендуемый поток:

```text
Godot/Jolt contact
    ↓
typed ImpactEvent
    ↓
generic Impact Damage System
    ↓
source veto / target eligibility
    ↓
mass + relative normal speed + contact impulse
    ↓
optional C_ThrowDamage
    ↓
receiver resistance / protection
    ↓
DamageRequest(Type.IMPACT)
    ↓
S_Damage
    ↓
C_Health
```

Entity bridge не должен напрямую уменьшать Health.

### Deduplication

Impact processing обязан отличать новый удар от продолжающегося contact.

Нельзя получать:

```text
коробка лежит на полу
frame 1 -> damage
frame 2 -> damage
frame 3 -> damage
...
```

Cooldown/contact-pair state/impact token или эквивалентный механизм должен иметь явный owner и очищаться при separation/removal.

---

## Impact severity

Для gameplay/UI/tuning физический impact классифицируется как минимум на:

- `NONE`;
- `WEAK`;
- `MEDIUM`;
- `STRONG`.

Severity является производной от рассчитанного физического события, а не заменой количественного damage.

Она нужна для:

- readable tuning;
- Package Fragile rules;
- Bubble Wrap tiers;
- feedback;
- будущих gameplay reactions.

---

## Package Damage

Package использует тот же `C_Health + C_ImpactReceiver`, что и любой другой damageable physical Entity.

Package реагирует на:

- сильный удар;
- падение;
- столкновение с другим предметом;
- бросок;
- недопустимый наклон;
- намеренное вскрытие.

`C_PackageState.Damage` хранит lifecycle/presentation state `UNDAMAGED/DAMAGED/DESTROYED`, но не является HP authority.

Правила:

- применённый Health damage переводит целую Package в `DAMAGED`;
- Health == 0 переводит её в `DESTROYED`;
- Damage/Destroyed state обновляется package-owned Observer/System на основании общего damage result/Health;
- ноль Health может стать trigger для Hazard;
- деньги не списываются непосредственно при повреждении.

---

## Bubble Wrap

Package может иметь модификатор защиты «пузырчатая пленка».

Защита имеет tier и работает поверх generic impact pipeline:

- impact severity до поддерживаемого tier включительно полностью блокируется для этой Package;
- более сильный impact проходит дальше в обычный damage calculation;
- Bubble Wrap не делает Package бессмертной против любого `DamageRequest`;
- защита не должна влиять на Toxic/Melee/другие damage types, если это отдельно не задано данными.

Protection state независим от Inventory item. Сам Consumable Bubble Wrap и его применение реализует R19.

---

## Fragile

Fragile — не отдельная формула damage.

Fragile меняет data-driven impact tolerance/resistance Package так, чтобы при одинаковом физическом событии она повреждалась раньше/сильнее обычной Package.

Не писать:

```gdscript
if package_is_fragile:
    damage *= MAGIC_NUMBER
```

в generic impact System, если то же правило может быть выражено profile/modifier data.

---

## Heavy

Heavy влияет на физику через реальную массу и существующие carry settings.

Большая масса естественным образом должна увеличивать потенциальный outgoing impact damage через generic physical formula. Не добавлять отдельный `if Heavy -> extra damage`, если масса уже выражает требуемое поведение.

---

## Liquid

Liquid имеет допустимый наклон относительно вертикали.

Если Package достаточно сильно/долго перевернута:

- содержимое портится;
- Package получает Damaged/Leaking;
- при соответствующем содержимом появляется Hazard.

Tilt damage/state не является collision impact и должен идти отдельным package-owned producer через общий `DamageRequest`, когда требуется уменьшение Health.

---

## Вскрытие и присвоение

Игрок может вскрыть любую физически доступную Package по собственному решению. Игра не должна запрещать действие только потому, что Package принадлежит Customer.

Package получает `Opened`, а состояние сохраняется столько же, сколько живёт сама Package.

Вскрытие может:

- ухудшить Customer Satisfaction;
- изменить вероятность отказа/жалобы/aggression;
- привести к штрафам или будущей потере Reputation;
- запустить опасное содержимое;
- дать Player физический доступ к содержимому, если соответствующая механика уже реализована.

Terminal показывает содержание и стоимость, поэтому некоторые Package намеренно создают морально-экономический соблазн: содержимое может быть полезнее Player, а расчётная стоимость Package — ниже рыночной цены аналогичного товара у Trader.

---

## Hazards MVP

### ToxicLeak

При разрушении подходящей Package создается опасная зона жидкости.

Она может:

- наносить periodic damage через общий `DamageRequest`;
- воздействовать на любой Entity с `C_Health`, если правила hazard допускают target;
- оставаться физическим препятствием/опасностью некоторое время.

### Explosion

При критическом damage подходящей Package:

- происходит взрыв;
- radial damage идёт через общий `DamageRequest`;
- физические тела получают impulse независимо от наличия `C_Health`.

Hazard implementation принадлежит R09.

---

## Экономическое последствие

Damage/Opened не обязаны немедленно списывать деньги.

Состояние Package сохраняется до Customer Delivery.

Если Customer пришёл за повреждённой Package — применяется penalty/reaction.

Если клиент за ней не пришёл, прямого штрафа может не быть.

---

## Критерий готовности

- Любой Entity с `C_Health` принимает обычный damage через общий pipeline.
- Collision damage получает только Entity с `C_Health + C_ImpactReceiver`.
- Маленький лёгкий предмет не способен нанести огромный physical damage тяжёлому объекту без специальных данных.
- `C_ThrowDamage` добавляет damage только валидному броску, а не любому contact предмета.
- `C_NoDamage` гарантированно запрещает исходящий damage своего Entity и имеет приоритет над `C_ThrowDamage`.
- Player/Customer/Package не требуют разных формул impact damage.
- Package использует `C_Health` вместо отдельного HP authority и сохраняет `Damaged/Destroyed` как package state.
- Fragile повреждается от более мягкого обращения, Bubble Wrap блокирует разрешённые impact tiers, Liquid реагирует на длительный наклон.
- Повторный physics contact не создаёт damage каждый кадр.
- R09 может поверх этого contract реализовать ToxicLeak/Explosion без второго damage pipeline.
