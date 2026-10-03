# Current Work

R27 QA fix OWNER_QA — исправлено появление двух клиентов внутри одного GECS CommandBuffer. Query cache до конца пакета оставался пустым; spawn_next_due и customer_for теперь читают текущие World.entities/C_CustomerAgent без дополнительного состояния очереди. Authoritative state: agent_tasks/roadmap_27_customer_queue.md.

Validation: before regression0/1 FAIL с2 NPC; после timing9 + flow27 =36/36,263 assertions PASS (.export/r27-batch-arrival-after.log). Повторный tick не закрывает первый визит и оставляет второго в очереди. Related diff --check PASS. Full/rendered не запускались.

Windows ab42a1bc: main .export/windows/20261003-112039Z-ab42a1bc-single-customer-main/PVZInHell.exe; test .export/windows/20261003-112205Z-ab42a1bc-single-customer-test/PVZInHell.exe. Оба menu120 + actual-level120 headless startup PASS, .export/LATEST.cmd и TEST_LEVEL.cmd обновлены. Следующий шаг — повторить owner QA двух клиентов в основной сцене по qa_tasks/customer_queue_and_push.md. Полный основной срез выполняет владелец.

Прежние задачи/статусы: agent_tasks/CONTEXT.md; R30 PNG/icons и R34 menu/save OWNER_QA, R31 DONE. R25 Russian documentation LAST после предыдущих задач и QA fixes. Только dev, master read-only; не трогать пользовательские scene/world/UI/roadmap23/definition/addon/raw-asset изменения. История task_history.md → archive0003; ротация после12KiB. Лимиты .codex не менялись.
