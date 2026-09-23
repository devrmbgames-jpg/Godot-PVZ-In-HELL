# Current Work

- Active: R08 / M5 complete, M5.1 next. User base ac76ce3 includes completed throw changes, C_NoDamage, O_Damage and new C_Health.current semantics.
- Preserved user Observer damage architecture: value = computed max HP, current = remaining HP. Common service snapshots requests; O_Damage owns arithmetic and source veto. No S_Damage restoration.
- User owns ALL runtime/tests; static checks only. Dirty addons/gecs preserved.
- Next: M5.1 gate: extract ImpactCaptureSolver + typed event inbox, narrow S_ThrowLifetime iterate query, neutral relationship helpers; no Grab/Cart/Push refactor.
