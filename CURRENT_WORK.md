# Current Work

R23/R24/developer_console_testing и R26–R30: OWNER_QA. Реализация текущей игровой очереди готова к ручной приёмке. Полный основной игровой срез, реальные устройства, визуальное оформление и звук по явному запросу проверяет владелец. Исправлять замечания в соответствующей существующей задаче; player checklists — qa_tasks/README.md.

Финальные Windows QA: gameplay commit be10abab, dev. Main: .export/windows/20261003-074906Z-be10abab-settings-input-final-main/PVZInHell.exe; test: .export/windows/20261003-075037Z-be10abab-settings-input-final-test/PVZInHell.exe. Обе actual-scene headless startup120frames PASS; .export/LATEST.cmd / TEST_LEVEL.cmd обновлены. Build_info отмечает пользовательские dirty files и player_qa PENDING.

R26 auto receive/CarryPlacement; R27 strict-one queue; R28 физические contents/all8 supply profiles/safe empty shell; R29 native small-body push; R30 1416 AtlasTexture .res + settings/rebind/persistence/UI icons. Подробные контракты/результаты в agent_tasks/roadmap_26…30. Последний полный крупный milestone471/471,3914,54 scripts (.export/r30-milestone-full-gut.log); actual-main settings_input smoke PASS20261003-173619701. Последующее локальное pause-input исправление be10abab: только drop3/3,16 (.export/r30-pause-drop-gut.log), полный прогон не повторялся. Review R30 R1 modifier overlap FIXED/confirmed; R2 pause buffered input FIXED. Structure/diff PASS; formatter не запускался.

Следующий шаг: дождаться owner QA main_level полного дня/следующего утра, controls/device/audio/UI; исправить воспроизводимые проблемы. R25 documentation DEFERRED/LAST — после предыдущих задач и их QA-исправлений; работать подсистемами, только русские ##/смысловые регионы и отдельные docs commits.

Dev only; master read-only. Preserve пользовательские main_level UID resaves, project settings reorder, addons/gecs, дополнительные raw Kenney assets. Настройки/назначения хранятся отдельно от gameplay snapshot; XML fallback одноразовый только при отсутствии .res. История task_history.md, archive0002; порог архива12КиБ.
