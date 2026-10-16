# Посылки — фактический состав, упаковка, история и UI

Результат: **IN_PROGRESS**. Все6 случаев начаты: body/terminal/detail/history/isolated restore проверены. Opening/rupture/repeat guard и финальная приёмка ещё не завершены.
Владелец разрешил до **6** проверок по этой карточке; начато **6/6**, завершено0/6. Дополнительные случаи не запускать. Разрешение не охватывает визуальную приёмку реакций NPC.
Программный checkpoint: `b0bee51b3a9c7c6dbacd59de1a304554f42a99a7`, независимое review PASS.
Owning task: [package_contents_and_packaging_consistency](../../.agents/tasks/package_contents_and_packaging_consistency.md).

Запуск готовой Windows QA-сборки: [LATEST.cmd](../../.export/LATEST.cmd).
Проверить commit и `working_tree_dirty` в `build_info.json` рядом с исполняемым файлом.
Готовая сборка: `20261016-021143Z-5018724c-cargo_history_ui`, export/menu120/level120 PASS,
`working_tree_dirty=true` из-за сохранённых прежних изменений рабочего дерева.
Не использовать старую сборку R28 для приёмки этого checkpoint.

Каждый случай ниже считается одной проверкой. Использовать фактически поступивший состав:
выбранный предмет, количество и упаковка уже зафиксированы до появления тела.
Если нужный состав ещё не появился, оставить соответствующий случай NOT_RUN.

| Случай | Ожидаемый результат |
| --- | --- |
| 1. Holy artifact ×1 | Маленькая подходящая коробка, полный вес 1.3 кг. Нет «ЖИДКОСТЬ», «ХРУПКОЕ», «ТЯЖЁЛОЕ», протечки или чужого разлива. История и terminal detail показывают артефакт. |
| 2. Blood flask ×1 | Жидкость и хрупкость обозначены на коробке и в терминале; полный вес 1.1 кг. При вскрытии выходит один целый предмет; при отдельном разрыве содержимого появляется один соответствующий разлив. |
| 3. Fire flask | В терминале видна огненная опасность вместе с жидкостью/хрупкостью. Эффект относится к настоящему содержимому и не повторяется у пустой коробки. Количество совпадает с записью. |
| 4. Acid barrel ×1 | Подходящая широкая упаковка для одной бочки, полный вес 20.5 кг. Жидкость, токсичность и тяжесть видны; метка хрупкости не возникает из прежнего рецепта. |
| 5. Toy block ×8 | Большая коробка, название с ×8, полный вес 6.0 кг. Выходят ровно восемь отдельных предметов. Нет ложной тяжести или жидкости; сортировка терминала по весу соответствует detail. |
| 6. Scythe ×1 | Длинная упаковка подходит физическому предмету; полный вес 5.5 кг. Диагностический размер oversized, количество один, без ложной жидкости. |

В каждом выполненном случае сравнить название/количество, stickers, terminal row/detail и историю.
После вскрытия коробка легче и без предупреждений о прежнем грузе; повторное открытие/разрушение
не создаёт содержимое заново. Архив сохраняет исходный полный вес, количество и опасности.
При безопасном сохранении и загрузке текущей схемы состав, номер, получатель и архив не меняются.
Старые неподдерживаемые схемы отклоняются с сохранением файла по решению владельца.

Дата / build commit / устройство управления:
2026-10-16, live Godot4.7.1/MCP на `14f4c83fd39077b74c49f5de48369dbaabdd9375` + сохранённые прежние dirty edits; primitive_test_level, QA slot `user://qa_cargo_fd0dda76_manual.pvzh`. Frozen Windows build выше для текущей приёмки не использовался.

Результат по случаям 1–6 (PASS / FAIL / NOT_RUN):

Замечания: package_id/history_id, шаги воспроизведения, ожидаемое и фактическое поведение.
QA-001: `qa/cargo/fd0dda76/holy_artifact`, №006, UID1-06-NM00D. Authored hidden title fixed/reviewed in `865db6c21469e9b4475a54c1fd5e89f701018247`, visual visibility PASS. Height180 instead140 needed for icon rows to contain visible title; native fix/targeted review pending. Evidence `.artifacts/cargo-qa-fd0dda76/{01..06}-*-{body,terminal}.png`, history `01-holy-history.png`, initial failure `01-holy-terminal-hidden-title.png`. All6 native shipments retained in isolated slot; scythe placement succeeded after unloading5 old boxes. A diagnostic eval invalid Entity/Node3D type check stopped helper; restart restores retained fixtures, no production code change.
