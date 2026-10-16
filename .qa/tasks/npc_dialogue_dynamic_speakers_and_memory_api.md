# Диалоговая UI приёмка — актуальное имя и авторская память

Owning task: [.agents/tasks/npc_dialogue_dynamic_speakers_and_memory_api.md](../../.agents/tasks/npc_dialogue_dynamic_speakers_and_memory_api.md).
Status: **PASS**. Reviewed runtime: `45cb14b55fddea92bf6d1bbc694c856b24fb2b64`.
Разрешение: указание владельца 2026-10-17 не спрашивать при неисчерпанном лимите.
Лимит milestone8; подготовлено3 случая. Использовано **3/8**, все3 подготовленных случая PASS; дополнительных запусков нет.
Это отдельная UI приёмка D1–D3; physics/H4/C4 бюджеты не используются и не возобновляются.

| № | Один случай | Критерий | Результат |
| --- | --- | --- | --- |
| 1 | Native authored Brute room: показать street и service ветку одного NPC в существующей CustomerDialoguePanel. | Speaker совпадает с постоянным именем, choices/cues сохранены, modal закрывается. Подготовленная service phase — UI fixture, не приёмка очереди. | PASS: street/service speaker=Бран, authored choices сохранены; Escape panels0/focus0, service modal6. PNG/JSON case1. |
| 2 | Скомпилированный пример docs/dialogue_memory.md в настоящей панели: первое/повторное знакомство и независимость коллекции от экземпляра ctx. | Первая ветка newcomer, повтор remembered; ключ не хранится в панели, закрытие возвращает ввод. Сам пример не канон и не списание денег. | PASS: first newcomer/repeat remembered; E закрыл панель, focus0; новый ctx читает visited, late writes не прошли, missing value не создан. PNG/JSON case2. |
| 3 | Native authored Angel room: открыть существующий sign-mode UI. | Табличка сохраняется, обычная речь/общий balloon не заменяют её; имя остаётся личным. | PASS: actual sign READABLE, «ЗАКАЗ №001 / УПАКОВКУ НЕ ВСКРЫВАТЬ», panels0/focus0, обычные street/customer dialogue gates false. PNG/JSON case3. |

Обычные save-слоты не трогать, использовать authored isolated rooms без save path.
Скриншоты/метрики: `.artifacts/qa_dialogue_memory_45cb14b5/`.
Каждый начатый случай расходует лимит при любом результате. Не повторять автоматически ради PASS.
Disk/fresh/retained/negative data и два NPC проверены native GUT+двухпроцессным smoke;
rendered случай не выдаёт повторно эти результаты за ручное доказательство.


Native MCP runtime действия завершены; PNG фактически просмотрены, JSON сохранены.
Case3 current-run game logs без новых ошибок. Queue/physics/переноски не проверялись повторно.
Все три случая используют существующие editable room/NPC/UI, без authored ресурсных правок.
Для street/service подготовлены роли/позиции и использован реальный ctx/panel; это приёмка
отображения/памяти/focus, не повторная приёмка всей очереди. Source двух NPC одного archetype
и persistent roundtrip покрывают отдельные native GUT/smoke из owning task.
