# ТЗ 09 — Диалоги

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
- обнаружение ложной отметки `TAKEN` и переход в Aggressive.

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
