# QA-CMP01 — Честный исход resolve_now в debug-жалобе

Status: **PLANNED**
Priority: **P2**
Baseline: `dev` / `229753cf92572354f5f3be803ff7d6cd931f43c5`

## Task state

### Goal

DebugCustomerService.complaint(resolve_now=true) не должен писать «complaint resolved», если CustomerOutcomeService оставил outcome=PENDING. Сохранить смысл success как принятого создания жалобы и штатный расчёт; уточнить message по фактическому outcome. Дефект выделен при [DOC01](pvz_code_documentation_quality.md), отдельно от comment-only batch.

### Current

Source evidence: debug_customer_service.gd после void resolve_complaint безусловно выбирает message по входному resolve_now. CustomerOutcomeService.resolve_complaint возвращается с PENDING, если wallet отсутствует либо WalletService.apply отклонён. Это не требует физического NPC. Runtime reproduction ещё NOT_RUN; проверить минимальный реальный visit при отсутствующем wallet, затем успешный расчёт при доступном wallet.

### Acceptance

- [ ] Focused regression подтверждает неверный message при PENDING.
- [ ] Message различает созданную pending-жалобу и terminal outcome; success создания не меняется.
- [ ] Реальный resolve по обычному pipeline и повторный вызов сохраняют историю/денежную идемпотентность.
- [ ] Relevant GUT/parser/MCP/style/static checks и immutable commit/review/triage PASS.

### Validation

NOT_RUN — зарегистрирован отдельный scope; production behavior пока не изменено.

### Owner QA / blockers

Gameplay/visual NOT_RUN, budget 0/8; для строковой диагностики достаточно headless regression.
