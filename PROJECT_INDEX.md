# Project Index

Optional routing map. Read only when the task does not already identify the owning subsystem/path.

| Concern | Start here |
| --- | --- |
| Startup / scheduling | `content/scenes/main_level.gd`, `content/scenes/main_level.tscn` |
| Cross-system gameplay architecture | `content/ARCHITECTURE.md` |
| Gameplay owner and its roles | `content/domains/<owner>/<role>/`, `content/domains/README.md` |
| Cross-domain foundations | `content/shared/<role>/`, `content/shared/README.md` |
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
| Raw input / intent | `content/domains/interaction/systems/` |
| Motion / look | `content/domains/motion/solvers/` |
| Interaction targeting / actions | `content/domains/interaction/systems/`, `content/domains/interaction/services/` |
| Grab / carry / push | `content/domains/interaction/services/`, `docs/physical_grab.md` |
| Cart | `content/domains/interaction/services/cart_transport_service.gd`, `docs/cart_transport.md` |
| Damage / impact | `content/domains/combat/services/`, `content/domains/combat/observers/o_damage.gd`, `docs/damage_impact.md` |
| Packages / receiving | `content/domains/packages/entities/`, `content/domains/packages/services/` |
| Hazards | `content/domains/hazards/`, `docs/hazards.md` |
| Customers / commerce | `content/domains/customers/`, `content/domains/commerce/`, `docs/customers.md`, `docs/economy.md` |
| Day cycle | `content/domains/time/systems/s_day_phase.gd` |
| Persistence | `docs/persistence.md` |

For version-sensitive APIs inspect the checked-out dependency source. Do not expand this index into a second architecture document.
