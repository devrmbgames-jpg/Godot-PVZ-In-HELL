# PVZ-A01 — нативная сцена торговой панели

Status: **OWNER_QA**
Technical: **COMPLETE**
Execution order: **30**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`
Source: [полное исходное ТЗ и доказательства](references/task-refactor-2026-10-17/pvz_a01_commerce_panel_scene_first.md.txt).

Эта карточка владеет текущим исполнением. Полный объём требований сохранён в Source;
правила чтения и автономного продолжения — в [README](README.md).


## Goal / acceptance

Редактируемая CommercePanel.tscn вместо постоянного макета из GDScript, без редизайна
и изменения экономики. Все scene bindings, оба режима, подтверждение/отмена, focus,
единственность панели и cleanup из Source остаются обязательными.

## Current

Техническая реализация и read-only review приняты по записанным evidence.
BASE_SHA: `160ab9c9caa872ccb748ab0fc1d64bdd21c15b7b`.
TARGET_SHA: `01af39e1a126e0d1326e474e164efe10d24bfe1b`.
Native scene, factory/quest callers и onready bindings уже перенесены; динамические строки допустимы.
Нельзя повторно строить эту панель только потому, что общий Status не DONE.

## Work packages

| Пакет | Состояние |
| --- | --- |
| U1 | Scene-first перенос, callers, input/lifecycle и технические проверки: COMPLETE/review PASS. |
| U2 | Прежний вид/читаемость, keyboard/gamepad focus и целевые устройства: OWNER_QA. |

## Entry points / dependency gates

content/ui/commerce_panel.gd, commerce_panel.tscn, commerce_panel_factory.gd,
существующие TraderPurchase/RefusalQuest fixtures. Другие панели и редизайн вне scope.
Технический U1 доступен задачам торговли; U2 не является глобальным блокером.

## Next

Без task-specific разрешения/owner evidence оставить U2 открытым и продолжить
независимую задачу. При разрешённой приёмке выполнить исходную матрицу; исправлять
только подтверждённую регрессию, не проводить новый архитектурный проход панели.

## Validation / review

Импортировано: TraderPurchase 29/29 + RefusalQuest 14/14, 523 assertions;
native layout compare equal=true/exit 0, parser/MCP/formatter/architecture/structure PASS.
Read-only review указанного BASE→TARGET PASS, reviewer execution NOT_RUN.
Это evidence исторического checkpoint, не повторно выполненные проверки текущего HEAD.
Новые runtime/visual проверки данного рефакторинга: NOT_RUN.

## Owner QA / blockers

Обязательная ручная приёмка открыта, recorded visual 0/8. Автовыдача не даёт разрешения U2.
До её выполнения/явного решения владельца не DONE и не архивировать.
