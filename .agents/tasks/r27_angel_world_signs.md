# R27.3 — мировые таблички Ангела

Status: **OWNER_QA**
Technical: **COMPLETE**
Execution order: **40**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`
Source: [полное исходное ТЗ и доказательства](references/task-refactor-2026-10-17/r27_angel_world_signs.md.txt).

Эта карточка владеет текущим исполнением. Полный объём требований сохранён в Source;
правила чтения и автономного продолжения — в [README](README.md).


## Goal / acceptance

Native 3D sign/Label3D показывает только актуальное намерение коммуникации, не имя
или idle fallback. Замена текста видима через ERASING/WRITING/READABLE, без обычной
диалоговой панели и без влияния presentation на действия/номер/наблюдение/заморозку.
Все lifecycle, cue, pause и исходные проверки Source остаются в приёмке.

## Current

Последний follow-up технически выполнен и reviewed.
BASE_SHA: `fb1c3d5b4081a2c2b4f5e99d490c31b2df460b07`.
TARGET_SHA: `c66bff73e70d88fb7c0d9eeb245c3adc859310bd`.
Старые разделы «Planned follow-up» описывают уже выполненный контракт, не новую очередь.
Статус уточнён до OWNER_QA без присвоения новых PASS.

## Work packages

| Пакет | Состояние |
| --- | --- |
| W1 | Native sign, typed projection и отказ от modal sign-mode: COMPLETE. |
| W2 | Только актуальная коммуникация, постепенная смена текста, cleanup/pause: COMPLETE/review PASS. |
| W3 | Наблюдаемость перехода, отсутствие idle board и читаемость: OWNER_QA. |

## Entry points / dependency gates

NpcSignboard, CustomerPresentation, NpcSignTextRequest и native prefab из Source.
Shared gameplay state остаётся read-only для presentation. Реальная анимация царапания
не входит в этот follow-up; её отсутствие не повод расширять W2.

## Next

Сохранить W3 открытым и продолжить следующую готовую техническую задачу, пока нет
разрешения/evidence владельца. При task-specific QA проверить look-away/look-back,
смену текста и legibility; не запускать её под разрешением чужой карточки.

## Validation / review

Исторический follow-up: 73/73 tests, 1130 assertions, native parser 4/0,
MCP/formatter/architecture/structure PASS, immutable review PASS без открытых findings.
Reviewer execution NOT_RUN. Полные журналы и prior evidence в Source; новые runtime
проверки на этом refactor не выполнялись. Visual recorded NOT_RUN, 0/8.

## Owner QA / blockers

Erase 0.3s/write 1.4s остаются прототипными настройками, не подтверждённым балансом.
Финальная приёмка открыта. W3 не блокирует использование принятого sign-контракта соседями.
