# ТЗ 09 — Диалоги

> **Implementation coverage:** Implementation coverage: dialogue integration **R12**, perception/distortion hooks **R18**.

## Цель

Создать простой диалоговый слой для Customer, Trader, Quest и horror events.

## MVP возможности

Dialogue поддерживает:

- последовательность реплик;
- speaker;
- варианты ответа;
- переходы между nodes;
- простые conditions;
- запись flags;
- изменение Satisfaction;
- передачу package number;
- запуск Challenge;
- запуск Aggressive state;
- завершение разговора;
- добровольный отказ Customer от Package;
- подачу/отложенное создание Complaint;
- обнаружение ложной отметки `TAKEN` и переход в Aggressive;
- ветку отказа/переговоров с короткими response intent tags;
- повторный разговор по unresolved Package case.

## Gameplay Context

Conditions должны уметь учитывать:

- CurrentDayPhase;
- Hunger tier;
- состояние RequestedPackage;
- quest flags;
- Customer Satisfaction;
- результат Challenge;
- фактический исход RequestedPackage;
- Terminal declaration;
- Customer Complaint/dispute state;
- была ли Package Opened/Damaged;
- подтверждена ли неправомерная Complaint.

## Negotiation intents

Dialogue response может нести короткий intent-tag:

- `[#hon]` — честность;
- `[#lie]` — обман;
- `[#prs]` — убеждение/отсрочка;
- `[#thr]` — угроза;
- `[#flr]` — флирт;
- `[#jok]` — шутка/отмена отказа.

Tag описывает намерение Player, а не прямой эффект. Satisfaction, Complaint chance, Aggression chance и вероятность follow-up принадлежат data-driven реакции конкретного `DEF_Customer`. Одинаковый `[#flr]` поэтому может успокоить одного Customer и раздражать другого.

`[#jok]` сам по себе не создаёт фактический отказ. Остальные intent-ветки могут закончиться фактом `PLAYER_DENIED` через gameplay service, а не через DialogueManager mutation данных напрямую.

## Package Number

Обычный Customer может сообщить номер прямо в Dialogue.

Номер должен оставаться обычной игровой информацией: Player должен сам запомнить/сопоставить его с физической коробкой.

## Riddle Customer

Один Customer сообщает номер только после простой загадки.

Неправильный ответ:

- уменьшает Satisfaction;
- дает повтор;
- либо переводит разговор на альтернативную ветку.

## Hunger Distortion

При высоком Hunger текст NPC искажается.

Для прототипа достаточно заменять воспринимаемые Player реплики другими персонажами на варианты:

```text
«Съешь меня»
```

Gameplay transitions Dialogue при этом остаются корректными.

## Критерий готовности

Есть прямой Dialogue с номером, Dialogue с выбором/загадкой и визуальное искажение текста при высоком Hunger.
