# NPC decision boundary

Keep a future LimboAI adapter thin. Existing visit/challenge owners select their
service phase; native solvers and NavigationAgent own movement/avoidance.

| Intent | Existing API / authority |
| --- | --- |
| Move to a point | NpcIntentService.move_to, C_NpcIntent |
| Follow / watch an Entity | NpcIntentService.follow/watch, R_NpcMoveTarget/R_NpcLookTarget |
| Stop / face movement | NpcIntentService.stop/look_along_movement |
| Bind / end combat | CombatService.bind_target/end_combat, R_CombatTarget |
| Read available attack choice | NpcAttackService.choose returns detached NpcAttackChoice or null |
| Execute chosen ability | NpcAttackService.start(actor, choice.kind, choice.variant) revalidates |
| Animation hit / end | E_NpcCharacter.npc_attack_hit / npc_attack_finished |

`choose` considers at most three melee and three ranged abilities. It evaluates
actual range, line of sight, phase and cooldown through the runner's eligibility.
Higher authored `DEF_NpcAttack.selection_priority` wins; equal priority prefers
estimated damage per authored attack cycle, then stable melee/ranged/index order.
This small estimate is a default selection policy, not a full tactical AI.

For external attack decisions set `C_NpcCombat.automatic_attack_selection = false`.
S_NpcCombat continues cooldown/timed/animation execution while the adapter calls
the existing start API at its own decision boundary. Request semantic intent;
do not write body transform/velocity or call a System as a helper. Do not compete
with CustomerFlow over visit navigation; integrate the adapter at the owner of
the applicable phase. Decision results contain no live Entity target authority.
