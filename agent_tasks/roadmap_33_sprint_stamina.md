# R33 — Бег и выносливость

Status: **OWNER_QA**

## Task state

### Goal

Бег на Shift/нажатие левого стика; удержание или переключение в настройках. Компонент выносливости: 70 + 30 × сила; 100 единиц хватает на 60 секунд бега без груза; груз увеличивает расход в 1.5–8 раз.

### Milestones

M0: компонент/владеющая система и скорость. M1: input/settings/HUD/persistence. M2: целевые проверки, один полный milestone, Windows QA build.

### Decisions

Опоры: отзывчивость, понятный расход, выбор между скоростью и грузом. Цикл: бежать → видеть расход → отдыхать либо сбросить груз → продолжить. Начальные настраиваемые значения: ускорение ×1.5; восстановление 10/с после 2 с отдыха; после истощения нужен запас 20% для нового бега. Расход груза линейно зависит от доли текущего веса к пределу переноски. Стояние и упор в стену не расходуют выносливость; модальные окна/смерть/приседание сбрасывают переключённый бег. Все значения — именованные данные. 100/60 единиц/с фиксированно: сила увеличивает запас, а не расход.

### Current

M0–M1 реализованы. Компонент C_Stamina, Input S_Sprint after S_PlayerIntent; native solver читает C_Motion.sprint_multiplier. Main/test overrides явно содержат Stamina. Настройки sprint_toggle/default hold сохраняются отдельно; Shift/JOY_BUTTON_LEFT_STICK уже имелись в project.godot (не менялся). HUD шкала + debug conditions/timer, stamina_info/help. Snapshot сохраняет current/initialized и сбрасывает режим, в том числе при загрузке старого snapshot. Реализация завершена (ecd95df9). Windows main/test от этого commit экспортированы; actual-scene120-frame startup обоих PASS, launchers обновлены. Следующий шаг — owner QA. Старые задачи не отменены, R25 остаётся последней. Работа только в dev.

### Validation

Связанный GUT23/23,151 (.export/r33-related-gut.log). Native main raw input/settings pause smoke PASS tests/artifacts/sprint_stamina-20261003-183153671.log (5 → 7.5 м/с, reserve drain, toggle/release/pause). Полный milestone484/484,3996,55 scripts (.export/r33-milestone-full-gut.log). Финальная локальная граница тяжёлого груза:9/9,55 (.export/r33-heavy-load-gut.log); полный прогон не повторялся. Финальный native main smoke с реальным console parser PASS tests/artifacts/sprint_stamina-20261003-183557159.log. Независимый read-only review: R1 FIXED/confirmed; прежняя миграционная edge загрузки старого snapshot дополнительно закрыта. Rendered/audio/device QA не выполнялась.

### Owner QA / blockers

[Сценарий QA](../qa_tasks/sprint_stamina.md). Визуальное качество, звук и физические устройства проверяет владелец; полный игровой срез агент не запускает.


### Review findings

- R1/P2 FIXED: console parser дополняет пропущенные optional args пустой строкой; `_info` нормализует stamina target в self. Smoke проверяет bare `stamina_info` и `help stamina_info` через настоящий parser.


Windows main: .export/windows/20261003-084015Z-ecd95df9-gait-sprint-main/PVZInHell.exe; test: .export/windows/20261003-084159Z-ecd95df9-gait-sprint-test/PVZInHell.exe. Build_info: dev, player_qa PENDING, рабочее дерево содержит сохранённые пользовательские изменения.
