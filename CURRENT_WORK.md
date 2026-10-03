# Current Work

R34 OWNER_QA — главное меню и игровой save/load/new/main/exit реализованы; authoritative state agent_tasks/roadmap_34_main_menu_saves.md. Сохранение — безопасная Morning checkpoint, mid-visit state не сериализуется. Main/test bootstrap общий, слоты отдельные; invalid preflight сохраняет текущую сцену/паузу. Настройки пишутся при закрытии и успешных переходах. Следующий шаг — player QA qa_tasks/main_menu_and_saves.md.

Validation R34: related30/30,203; full491/491,4029,56scripts (.export/r34-milestone-full-gut.log); GUI pointer/session lifecycle smoke192144176 PASS; raw settings/binding safety input smoke192408372 PASS. Reviewer R1 FALSE_POSITIVE, R2 FIXED/confirmed. Structure/diff checks PASS. Rendered/full slice/device QA не выполнялись.

Предыдущие R23/R24/console/R26–R30/R32/R33 OWNER_QA сохраняются; R31 resources migration DONE. Их состояния и validation в agent_tasks/CONTEXT.md и task_history.md. R25 documentation LAST после предыдущих задач и QA fixes. Полный основной игровой срез выполняет владелец по его явному запросу.

Только dev, master read-only. Сохранять все пользовательские правки addons/gecs, main_level.tscn, definitions/navigation/raw Kenney assets. project.godot staged selectively только bootstrap migration. Настройки отдельно от gameplay snapshot. task_history.md/archive0002; архивировать после12KiB. Лимиты .codex не менялись. R34 gameplay97a0ef71; main .export/windows/20261003-092610Z-97a0ef71-menu-saves-main/PVZInHell.exe; test .export/windows/20261003-092744Z-97a0ef71-menu-saves-test/PVZInHell.exe. Оба menu120frames и actual-level120frames startup PASS, launchers обновлены. Два failed GUI logs1795bytes и временный index удалены; evidence сохранены.
