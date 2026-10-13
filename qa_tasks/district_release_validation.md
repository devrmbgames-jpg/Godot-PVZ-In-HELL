# Район — связная ручная приёмка итоговой Windows QA-сборки

Status: **PENDING_OWNER_QA**

Owning task: [district integration](../agent_tasks/district_release_validation.md).
Current runnable build: [PVZInHell.exe](../.export/windows/20261013-012719Z-4c60e3dc-r26-reviewed-pressure-qa/PVZInHell.exe).
Manifest: `.export/windows/20261013-012719Z-4c60e3dc-r26-reviewed-pressure-qa/build_info.json`; `.export/LATEST.cmd` points to this build.
Compiled gameplay checkpoint `4c60e3dc784352c2fb95ca617cebbafa9a834366` plus preserved
user changes (dirty=true); export/headless menu/level120frames PASS. It is not an immutable checkout.
External test-only connected checkpoint `1f37ddd1c3136c2b6094ed8c7131a3e9d2ce8dee`: native write/restore
PASS, exits0/0; exact-SHA targeted review ARCHITECTURE/STYLE PASS, reviewer VALIDATION NOT_RUN.
The binary was not re-exported for the fixture repair; gameplay/resources did not change.
Write wrapper FAIL only known shutdown retention; rendered/subjective owner QA NOT_RUN.
All-ten profiles/default ambient0.15/authored light timeout60s remain the manual QA scope.
Use a separate QA save profile; headless checks do not prove feel, readability or visual routes.

## Связное прохождение

- [ ] Первым утром осмотреть стоянку и дверь, разгрузить реальные коробки. Вынос/возврат
  меняет запрет начала смены. Для одной отсутствующей коробки заявить ручной LOST через
  терминал: запись остаётся без выдуманного номера, повторное действие не повторяет штраф.
  Проверить причины запрета и игрока в кузове по [gate](district_truck_shift_gate.md).
- [ ] До начала смены загрузить и снова извлечь обратный предмет. Затем проверить реальные
  возврат/продажу/утилизацию и однократную выручку по [грузу](district_truck_returns_resale.md).
  После разрешённого старта дверь закрывается, машина исчезает, выгруженные посылки остаются.
- [ ] Обслужить клиентов через обычный маршрут и действия игрока. На втором дне при свободном
  проходе следующие два NPC подготовлены, ожидание не превышает согласованные 10 секунд.
  Проверить световое предупреждение, ограниченное мерцание и конечное ожидание по
  [NPC-чеклисту](district_npc_stage_acceptance.md); прерывание не оставляет NPC занятым навсегда.
  Проверить штатный авторский 60-секундный timeout без вмешательства опасности:
  автоматический connected smoke использовал поддерживаемую 5-секундную test-only настройку.
- [ ] В терминале записать заметку, прочитать жалобу и уведомление. Получить и принять
  предложение доставки, проверить личный торг/отказ и выполнить реальную передачу коробки.
  Использовать [терминал](district_terminal_delivery_actions.md),
  [заметки](district_terminal_notes_complaints.md),
  [личный диалог](district_personal_delivery_dialogue.md) и
  [завершение доставки](district_delivery_completion.md). Обычная оплата и доплата однократны.
- [ ] Купить крупную мебель с доставкой. Попап и доплата соответствуют
  [торговцу](district_trader_purchase.md); следующим утром появляется один предмет на
  авторской площадке по [прибытию мебели](district_furniture_arrival.md).
- [ ] Пройти сон, полностью закрыть игру и восстановить прохождение. Проверить заметки,
  прочитанные уведомления, обязательства, мебель, население и следующую партию машины:
  повторных выплат, коробок, жителей и обработки груза нет.
- [ ] Завершить обязательные сценарии защиты несовместимого слота и явного New Game по
  [сохранениям](district_save_snapshot.md), используя только отдельные тестовые файлы.
- [ ] Зафиксировать результат по точной итоговой сборке, возникшие дефекты и решение
  владельца. Открытый обязательный пункт оставляет owning task в OWNER_QA;
  явно отложенный polish требует записанного решения и не выдаётся за PASS.

## Результат

NOT_RUN. Заполнить после фактического прохождения. Rendered gameplay/visual capture
агентом не запускались; решение владельца ещё не получено.
