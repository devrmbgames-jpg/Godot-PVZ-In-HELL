# Project Index

Optional routing map. Read only when the task does not already identify the owning subsystem/path.

| Concern | Start here |
| --- | --- |
| Startup / scheduling | `content/scenes/main_level.gd`, `content/scenes/main_level.tscn` |
| Cross-system gameplay architecture | `content/ARCHITECTURE.md` |
| Components / Relationships | `content/components/`, `content/relationships/` |
| Contracts / definitions | `content/contracts/`, `content/definitions/` |
| Entities / authored scenes | `content/entities/` |
| Systems / observers | `content/systems/`, `content/observers/` |
| Services / solvers | `content/services/` |
| UI | `content/ui/` |
| Tests | `tests/gut/`, `tests/smoke/` |
| Tooling | `utils/` |
| Design / mechanics docs | `docs/README.md` |
| Durable cross-session tasks | `agent_tasks/` |
| Manual acceptance | `qa_tasks/` |

## Common gameplay routes

| Concern | Start with |
| --- | --- |
| Character physics | `content/domains/motion/entities/e_rigid_body_character.gd` |
| Raw input / intent | `content/systems/input/` |
| Motion / look | `content/services/motion/` |
| Interaction targeting / actions | `content/systems/interaction/`, `content/services/interaction/` |
| Grab / carry / push | `content/services/interaction/`, `docs/physical_grab.md` |
| Cart | `content/domains/interaction/services/cart_transport_service.gd`, `docs/cart_transport.md` |
| Damage / impact | `content/services/damage/`, `content/domains/combat/observers/o_damage.gd`, `docs/damage_impact.md` |
| Packages / receiving | `content/entities/packages/`, `content/services/packages/` |
| Hazards | `content/services/hazards/`, `content/observers/gameplay/`, `docs/hazards.md` |
| Customers / commerce | `content/services/customers/`, `docs/customers.md`, `docs/economy.md` |
| Day cycle | `content/systems/gameplay/s_day_phase.gd` |
| Persistence | `docs/persistence.md` |

For version-sensitive APIs inspect the checked-out dependency source. Do not expand this index into a second architecture document.
