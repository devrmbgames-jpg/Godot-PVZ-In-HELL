# ТЗ 16 — HUD и игровая обратная связь

## Цель

Сделать системные состояния читаемыми, не превращая gameplay в управление через меню.

## HUD

Минимально:

- Health;
- Hunger;
- Crosshair;
- Interaction Prompt;
- Money — допустимо показывать постоянно или только в релевантных UI.

## Interaction Prompt

Возле Crosshair показываются только доступные действия.

Примеры:

```text
[E] Взять
[E] Отпустить
[LMB] Бросить
[RMB + Mouse] Вращать
[F] Использовать
```

## Package Feedback

Игрок визуально должен различать:

- Fragile;
- Heavy;
- Liquid;
- Damaged;
- Opened.

Основные PackageTags должны читаться на самой коробке: stickers/icons/marking, а не только через HUD.

## Terminal / Package Outcome Feedback

Terminal должен ясно различать:

- active Package;
- фактическое состояние Package;
- заявленный Player outcome: `Забрал / Отказался / Потеряна`;
- стоимость Package;
- pending/confirmed Complaint или dispute, когда Player уже должен о нём знать.

Terminal всегда сохраняет видимой последнюю Package, покинувшую активный складской lifecycle, чтобы результат последнего закрытия не исчезал мгновенно из UI.

UI показывает состояние, но не является authority settlement/complaint.

## Scanner Feedback

Successful Scan:

- beep;
- визуальное подтверждение;
- запись на Terminal.

## Challenge Feedback

Правила опасного Customer должны быть понятны через Dialogue и world feedback.

Примеры:

- Customer явно требует Light Off;
- Don't Look усиливает distortion;
- Keep Looking реагирует на потерю взгляда;
- timed action получает минимально достаточный countdown/feedback.

## Damage Feedback

Различать по ощущению:

- Player Damage;
- Package Damage;
- Toxic Hazard;
- Explosion.

## Критерий готовности

Без debug UI Player понимает, с чем взаимодействует, какие действия доступны, состояние Health/Hunger и основные последствия.
