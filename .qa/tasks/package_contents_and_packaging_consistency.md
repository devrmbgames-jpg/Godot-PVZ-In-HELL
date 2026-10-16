# Посылки — фактический состав, упаковка, история и UI

Результат: **PASS — 6/6 разрешённых случаев**, 6/8 лимита milestone. Дополнительные случаи не запускались.
Владелец разрешил шесть именованных cargo-сценариев; разрешение не относится к реакциям NPC.
Owning task: [завершённая задача](../../.agents/tasks/completed/package_contents_and_packaging_consistency.md).

2026-10-16, live Godot4.7.1/MCP, primitive_test_level, rendered1920×1080.
Финальный код: `594639d706c47edeffda8d9ff5b82e353fbd54b5`; прежние dirty edits сохранены.
Составы заданы QA через native ShipmentRules/ReceivingPackageFactory/registration.
Вскрытие выполнено штатным PackageOpening с реальным ray/хватом; предметы размещал LootDropService.
Субъективный gameplay feel и gamepad здесь не оценивались. Один случай включает перечисленные ниже действия.

| Случай | Фактический результат |
| --- | --- |
| 1. Holy artifact ×1 | **PASS**. package_a,1.3кг, без жидких/хрупких/тяжёлых предупреждений и чужих разливов. Один настоящий артефакт; пустая масса0.7кг. №006, UID1-06-NM00D. |
| 2. Blood flask ×1 | **PASS**. package_b,1.1кг, «ХРУПКОЕ/ЖИДКОСТЬ», соответствующие terminal icons. Один целый предмет при вскрытии; отдельный разрыв полной коробки создал ровно один blood_spill. Визуал разлива исправлен и виден над полом. Пустая масса0.7кг. №007, UID1-07-LS00B. |
| 3. Fire flask ×1 | **PASS**. package_b,1.1кг, fire/fragile/liquid icons. Один целый предмет; отдельный разрыв создал ровно один fire_spill. Повтора у пустой оболочки нет. Пустая масса0.7кг. №008, UID1-08-OS00B. |
| 4. Acid barrel ×1 | **PASS**. package_barrel,20.5кг, toxic/heavy/liquid icons и физические heavy/liquid метки без fragile. Одна реальная бочка; пустая масса2.5кг. №009, UID1-09-TL05P. |
| 5. Toy block ×8 | **PASS**. package_big,6.0кг, название ×8, восемь отдельных native предметов с quantity1. Нет ложных liquid/heavy warnings; пустая масса2.0кг. Весовая сортировка использует исходные6.0кг. №010, UID1-10-NL01O. |
| 6. Scythe ×1 | **PASS**. package_long,5.5кг, один предмет, diagnostic size X, без liquid. Пустая масса2.5кг. №011, UID1-11-NX01J. В занятый кузов не поместилась; после разгрузки5 прежних коробок штатный try_place успешен. |

Для всех6 body/stickers, terminal row/detail/history согласованы. Название и количество видны и помещаются в карточку.
Повторное вскрытие отклонено; повторный release создаёт0 предметов. Пустые коробки показывают «Пустая коробка» вместо cargo warnings.
Разрушение всех6 пустых оболочек создало0 новых hazards, повторный damage request отклонён; записи сохранили исходные title/quantity/full mass/UID/номер после удаления тела.
Сортировка по исходному весу:20.5/6/5.5/1.3/1.1/1.1кг.

Изолированные слоты: `user://qa_cargo_fd0dda76_manual.pvzh` (полные), `user://qa_cargo_fd0dda76_opened.pvzh` (пустые+13 предметов), отдельный QA autosave path.
Запись/preflight/restore обоих состояний PASS; после reload тот же состав, номер/UID и архив, повторный release0.
Неподдерживаемая schema22 в отдельном QA-файле отклонена; SHA256 файла и число Entity World не изменились.
Обычные слоты этой приёмкой не записывались.

QA-001/P2 **FIXED**: authored hidden title — `865db6c21469e9b4475a54c1fd5e89f701018247`; высота icon rows180 — `5694fab2edd8d1fb5976acd7b85ac9c06f5002fd`.
Оба immutable review architecture/style PASS, reviewer execution NOT_RUN; main visual visibility/containment PASS.
QA-002/P2 **FIXED**: тонкий blood disc был ниже пола при body_y=-0.01429; native Visual+0.03м — финальный код выше.
Review architecture/style PASS; visual bottom0.00569/top0.02573м, root/collision volume прежние.
Один диагностический eval с неверной Entity/Node3D проверкой остановил helper; fixtures восстановлены из QA-слота, production script не менялся.

Доказательства: `.artifacts/cargo-qa-fd0dda76/observations.json`; `01..06-*-{body,terminal,opened}.png`,
`05-weight-sort-layout-fixed.png`, `06-archive-after-opened-restore.png`, `02-blood-rupture-visual-fixed.png`, `fire_flask-rupture.png`.
Первоначальные неуспешные изображения сохранены. Снимки и записи просмотрены; это фактически выполненная приёмка.

Актуальная Windows QA: [LATEST.cmd](../../.export/LATEST.cmd), `20261016-060031Z-594639d7-cargo_acceptance`.
Export/menu120/level120 **PASS**, dirty=true из-за сохранённых прежних изменений. Изолированный профиль QA.
Rendered-приёмка выше выполнена через live MCP; player QA экспортированного бинарника **NOT_RUN**, как указано в build_info.json.
