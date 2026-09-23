# Current Work

- Active: R08 / M5.1 architecture gate implemented; user base ac76ce3 preserved (O_Damage and Health.current).
- Damage uses typed World event; no S_Damage. ImpactCaptureSolver writes C_ImpactInbox; S_Impact drains explicit iterate query and owns pairs. Pure formula in ImpactCalculation; ThrowContext is narrow pickup/throw seam, S_ThrowLifetime has its own iterate query.
- No new cross-System calls/service-locator; unchanged legacy Grab/Cart/Motion beyond narrow callback/throw seams remains R22.5.
- User owns ALL runtime/tests; static checks only. Dirty addons/gecs preserved.
- M5.1 committed 84f99be; M6 adds immutable receiver profiles, fragile supply data, living/parcel receiver opt-in and one-shot package condition initialization. Static checks only.
- Next: M6 commit, then receiver-side protection tiers (M7).
