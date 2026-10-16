# Выдача и чужие посылки — оставшаяся gameplay QA

Owner task: [automatic_parcel_handover_and_wrong_recipient_reactions](../../.agents/tasks/automatic_parcel_handover_and_wrong_recipient_reactions.md).

Status: **NOT_RUN**. Rendered/gameplay authorization for this task is not granted; cargo task's six approved checks were completed separately.
Budget: **0/8 cases** for this milestone. Headless GUT and MCP script diagnostics are separate evidence and do not establish gameplay feel.
Before execution: record the reviewed code SHA and runnable build path here, obtain task-specific authorization, then count each prepared case once. Use an isolated QA save; preserve owner saves and unrelated editor changes.

## Cases

| # | Prepared situation | Player action and acceptance | Evidence / result |
| --- | --- | --- | --- |
| 1 | Current rightful customer at the delivery counter; own registered parcel on the authored surface | Put the parcel down naturally. NPC takes it automatically, without F; ordinary inspection/payment occurs once. Nearby uncalled residents do not grab it. | NOT_RUN |
| 2 | Current rightful customer and a large own parcel in the player's Carry | Approach without aiming at the NPC. Handover uses the parcel surface strictly inside 1 m and clear LOS; no pull through a wall or premature handover outside reach. | NOT_RUN |
| 3 | Ordinary receiver offered a wrong registered parcel | Hear one refusal, remove and offer the parcel again. No message/grab spam within the pair's 180 active seconds; player can manipulate it immediately. Pause must not consume the block. | NOT_RUN |
| 4 | Brute actually appropriated a wrong parcel; prepared RETURN outcome; player hands free | Read and invoke the native demand action. The same parcel returns through one physical grip, with no payment or legal-recipient change. Repeated input cannot reroll or steal it back. | NOT_RUN |
| 5 | Same actual appropriation and RETURN outcome; player's Carry occupied; clear supported ground nearby | Demand return. Existing player item stays held; returned parcel is placed in reachable clear space, above support, without overlap or passing through solid geometry. | NOT_RUN |
| 6 | Actual Brute appropriation; prepared ATTACK outcome | Demand return and defend/retreat. Ordinary combat starts once, parcel remains physical, and repeated input or subsequent load cannot start another demand attack. | NOT_RUN |
| 7 | Chain Devil offered a wrong parcel; prepared throw outcome | Observe a real throw toward the captured player position, with a possible miss/obstacle and normal impact behavior. The parcel remains recoverable and is not counted as delivered. | NOT_RUN |
| 8 | Actual appropriation; RETURN outcome; occupied player Carry and no safe supported placement | Demand return: NPC keeps the real parcel and the prompt changes to claim it. Clear hands/space and claim again; captured outcome remains RETURN. Action must not prolong the normal service/departure clock. | NOT_RUN |

Probability distribution, holy/fire metadata and persistent record validation have focused native regressions in the owner task. These manual cases cover interaction and physical feel; do not present their NOT_RUN status as PASS or close the owner task before required acceptance is resolved.
