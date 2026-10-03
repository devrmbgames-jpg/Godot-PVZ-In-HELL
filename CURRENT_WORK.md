# Current Work

R31 DONE: content/resources/input_prompts → resources/input_prompts; SHA2561417 файлов unchanged, atlas1416/0 written. R32/R33 OWNER_QA: единая фаза шагов/bob, step_distance2.8, опускание поясных креплений; sprint Shift/left-stick-click hold/toggle, C_Stamina70+30×сила,100/60 drain, груз×1.5..8, recovery10/s after2s, restart20%. Main/test overrides явно включают Stamina. Обычная скорость main5м/с сохранена; sprint7.5. HUD/debug timers и stamina_info/help.

Validation: R32 feedback5/5,33. R33 related23/23,151; full milestone484/484,3996,55scripts (.export/r33-milestone-full-gut.log). После полного — только heavy-load9/9,55 (.export/r33-heavy-load-gut.log), без повторения full. Native main sprint/settings/console parser smoke PASS20261003-183557159. Reviewer R1 empty optional console target FIXED/confirmed; old snapshot session reset hardened. Rendered/device/audio QA не выполнялась; чек-листы qa_tasks/sprint_stamina.md и feedback_and_audio.md.

Следующий шаг: commit milestone R33 и последовательно Windows main/test exports (utils/export_windows.ps1). Обновить launchers/build evidence. Предыдущие R23/R24/console/R26–R30 OWNER_QA остаются; полный основной игровой срез выполняет владелец по его явному запросу. R25 documentation LAST после предыдущих задач и QA fixes.

Dev only, master read-only. Пользовательские addons/gecs, main_level UID/resource resaves, project settings reorder и дополнительные raw Kenney assets сохранять. Для main_level индексировать только собственную stamina migration: .export/r33-main-index.tscn = HEAD main + Stamina, worktree содержит также прежние user edits. Настройки отдельно от gameplay snapshot. task_history.md/archive0002; архивировать после12KiB. Лимиты .codex не менялись.
