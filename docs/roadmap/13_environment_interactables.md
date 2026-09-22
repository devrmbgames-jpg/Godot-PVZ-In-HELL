# ТЗ 13 — Двери, окна, мебель и свет

## Цель

Сделать помещение физически интерактивным и пригодным для хоррор-событий.

## Общий принцип

Все объекты используют общий interaction targeting/prompt framework.

Базовые contracts Door lock/open-close, Drawer movement, prolonged interaction и physical placement/storage определены в [ТЗ 08.1](08_1_arrangement_extended_interactions.md) и реализуются generic foundation-задачей R11.1. R13 должно применять и расширять их к окружению, а не создавать параллельные системы.

Не создавать отдельную систему взаимодействия для каждого типа объекта.

## Door

Должна:

- открываться;
- закрываться;
- блокировать проход;
- иметь читаемое состояние;
- поддерживать lock/access requirement через contract ТЗ 08.1.

Физические предметы должны иметь возможность мешать закрытию или блокировать проход.

## Window

Должно:

- открываться;
- закрываться;
- иметь состояние;
- позже участвовать в Customer/Monster events.

## Drawer / Shelf Drawer

Выдвижной элемент мебели должен:

- выдвигаться;
- задвигаться;
- иметь interaction state;
- переиспользовать open/close movement contract ТЗ 08.1;
- при необходимости поддерживать physical storage slots без отдельной drawer-only inventory system.

## Light Switch

Switch управляет одной или несколькими группами света.

Состояние света должно быть доступно Challenge System.

## Highlight

Выбранный interaction target получает ненавязчивое визуальное выделение или иной понятный feedback.

## Критерий готовности

Player через общий interaction framework открывает Door и Window, двигает Drawer и переключает Light; prompt всегда соответствует текущему объекту.
