# История выполненных задач

- 2026-09-21 — Изучен и проиндексирован проект, создана папка docs/ и контекст подсистемы gameplay.
- 2026-09-21 — Добавлен прыжок с земли в S_Jump с проверками ввода и импульса.
- 2026-09-21 — Реализованы физический хват, перенос, вращение и бросок коробок с весовыми профилями; пройдены 36 тестов.
- 2026-09-21 — Введены удаление завершённых файлов задач из agent_tasks/ и краткая история в task_history.md.
- 2026-09-22 — Исправлены RayCast-наведение, контур доступной цели, регистрация lifecycle observer и устойчивость физического переноса предметов; пройдены 37 GUT-тестов.
- 2026-09-22 — R01: physical packages with persistent IDs, immutable shipment definitions, composable tags and independent runtime state; smoke checks and 7 existing regressions passed.
- 2026-09-22 — R02: typed contextual actions, tool input reservation/Alt override, F/use, crosshair and gameplay-driven prompts; 31 existing grab regressions and standalone interaction smoke passed.
- 2026-09-22 — R03: authoritative four-phase day cycle, F-operated shift/sleep stations, schedule gating and Night persistence hook; full world-action cycle and existing grab regressions passed.
- 2026-09-22 — Playtest fixes: contextual E/F priority, phase announcements, frictionless character contacts, 1.25 m carry distance and direct held rotation; real physics and rendered HUD checked.
- 2026-09-22 — R04: typed queued damage/heal pipeline, bounded health, single defeat with grab cleanup and separate package integrity adapter; damage smoke and 37 existing regressions passed.
- 2026-09-22 — R05: deterministic eight-parcel morning supply, data-defined carry/hazard profiles, collision-safe receiving with blocked-space retry and preserved old parcels; next-cycle smoke passed.
- 2026-09-22 — R06: physical scanner with idempotent cycle-scoped registration, result feedback and current-cycle terminal; printer definition prepared, rendered flow and 37 existing regressions validated.
- 2026-09-23 — R06.1: Inspector-first components, independent Carry/two hands, nested capture, E/F/G/swap/rotation and physical Push; reusable warehouse numbers corrected; 64 GUT tests and five smoke checks PASS.
- 2026-09-23 — R07: hand-mapped physical marker, bounded package-local ink with visible-face projection and lifecycle cleanup, numbered physical shelves 01–06; 68 GUT tests, five headless smokes and rendered storage preview PASS; R21 ink persistence contract documented.
- 2026-09-23 — Cart correction: independent grounded reversible transport, assisted stacked cargo and pickup/lifecycle cleanup; S_Push unchanged; 67 relevant GUT tests and three headless smokes PASS, visual playtest user-owned.
