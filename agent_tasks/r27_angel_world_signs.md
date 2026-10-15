# R27.3 — таблички ангела в мировом пространстве

Status: **PLANNED**

Parent: [R27](r27_qa_followup.md).

## Task state

### Goal / acceptance

- Angel service cues appear on an authored3D sign object in front of the NPC with Label3D text.
- Sign text communicates the current recipient's request; player discovers it visually.
- Angel does not open the normal dialogue UI to display signs while frozen under observation.
- Preserve actual observation/freeze, parcel interaction/outcomes and typed dialogue/gameplay actions.
- Sign lifecycle follows participant/role/scene lifetime; no orphan signs after reset/transition/death.
- Native tests verify cue text/placement/lifetime and absence of normal sign-dialogue request.
- Owner follow-up: no actual communication means no board; generic name/hint is not a message.
- Text changes through a visible gradual transition, allowing an incomplete/ambiguous intermediate
  reading. The future scratching animation can use the same presentation phases.

### Current

Owner follow-up2026-10-15, planning only: hide the entire sign when there is no actual
communication; change its text gradually so the player can notice it being rewritten.
Future scratching animation should be able to reuse the same presentation transition.
This follow-up is not implemented. Older PASS evidence below covers only the prior checkpoint.

### Planned follow-up contract

- Native owner: [NpcSignboard](../content/domains/npc/presentation/npc_signboard.gd),
  [projection](../content/domains/customers/presentation/customer_presentation.gd) and
  [typed receipt](../content/domains/npc/contracts/npc_sign_text_request.gd).
  Current code sets visible=true whenever the NPC supports signs, uses STREET_HINT without a role,
  otherwise reads the generic Message label; it assigns the requested text immediately.
- Derive board presence from an actual current communicative intent: order number, request,
  delivery offer, warning or a deliberate dialogue line. No active intent/empty or whitespace-only
  text means the complete board is hidden. Remove permanent STREET_HINT/name fallback.
- A stale Message label or an assigned service role alone is insufficient. Clear the presentation
  when its request ends, the visit finishes, an offer expires or the role is removed.
- Use a small presentation sequence: show board -> write -> readable text; on replacement,
  gradually erase/fade old text -> writing interval -> gradually reveal new text.
  A primitive fade/reveal is sufficient now; actual hand/scratching animation is future work.
- Keep an incomplete intermediate state visible for a tunable duration; do not instantly complete
  a transition because the player looks at the angel. The player can catch the change in progress.
  Preserve the angel's physical observation/freeze contract during all text transitions.
- Repeated projection of the same intent/text must not restart writing every frame. A changed
  request replaces/cancels the previous transition; no late callback restores an obsolete number.
  Retire the old text as soon as its source is invalid, rather than presenting it as a live request.
- Partial displayed text is presentation only. Actions, current parcel number and delivery offer
  remain authoritative gameplay facts; a half-written line does not create/commit another action.
- No request: finish only an optional brief hide transition, then no visible empty board.
  Death, retirement, scene exit and role cleanup cancel pending transitions and hide immediately.
  Menus/pause follow the existing gameplay-presentation pause policy; no background request expiry.
- Author durations/style in native scene/resource data. Initial timings are a future tuning step,
  not an owner-approved delay. Expose write/erase phases so scratching animation can replace the
  primitive transition without changing dialogue/service state ownership.

### Planned follow-up validation

- GUT: idle/no request/finished visit/whitespace => hidden board; real order/offer => visible board.
- Transition: intermediate frame differs from the final line; writing can be observed; repeated
  identical requests do not restart it; A->B->C cannot finish with stale A/B; Cyrillic/multiline safe.
- Cleanup/death/pause/scene change: no stale callbacks, orphan boards or restored old text.
- Existing gaze-freeze, sign-only communication, order/delivery interactions and ordinary NPC
  dialogue retain their guarantees. Keep presentation read-only and shared resources immutable.
- Owner QA: watch a change, look away/look back during writing, confirm no permanent idle board
  and a legible completed request. Real scratching animation is not required for this follow-up.
- Current follow-up tests/visual QA: **NOT_RUN**; this turn plans work only.

### Prior implementation checkpoint

Source `d0568a32b4f80ab02a9ab8ab0d84babe341a91be`.
Existing weeping_angel variant_a/b dialogue and district NPC authored scene are the owner surface.
Implemented through native MCP: board/Label3D prefab in front of the NPC, with a typed
read-only projection receipt supplied by higher Customer composition. The native prefab never
imports Customer behavior. Registration/order/private-offer text derives from current records.
Both dialogue entry gates reject sign-mode NPCs; normal panel's old2D sign mode is removed.
Personal delivery offers can be accepted with the existing native request action and a contextual
caption, without mutating shared authored captions or opening a modal. Ordinary NPC panels remain.
Native cleanup hides/clears the sign and restores the replaced message view; scene ownership frees it.
Companion MCP gains bounded path diagnostics for new owned scripts and revision-based atomic
registration refresh; vendored Godot AI/GECS remain unchanged.

### Prior validation

PASS: native angel/world-sign37/701 (`gut-20261013-083446797`), customer dialogue15/272
(`gut-20261013-082141563`), native gaze freeze15/110 (`gut-20261013-082146715`),
owned diagnostics tool3/40 (`gut-20261013-082347471`):70tests/1123assertions.
PASS: parser14 (`parsefiles-20261013-083513191`), formatter, strict architecture, structure,
persistence inventory; declared only the new read/query/subscription public edges.
PASS: live MCP path-bound diagnostics checked/error_code0 across changed sources; executing
handler and base use checked compiled_handler source identity without reloading their bytecode.
Live plugin registered the new tool without editor restart or project settings writes.
Connected write `district_release-write-20261013-183807311.log` native PASS exit0;
fresh restore `district_release-restore-20261013-184552782.log` native PASS exit0 with result JSON.
Shutdown retention KNOWN_ENGINE_LIMITATION/DEFERRED.
Review PASS: base `136cfa18cbc5d6e9e0f20d5c8e58347ecdd2bf31`,
target `2636f85dd143841f8586827ba3ee996056b9456a`; sole reviewer completed without material findings.
Architecture/style PASS; reviewer validation NOT_RUN. UTC2026-10-13 08:51:49?08:58:29,400s.

### Owner QA / blockers

New follow-up implementation and owner visual acceptance remain open. Previous tests do not
verify the new no-message/gradual-writing requirements. Work is planned, not started.

### Next

Await a separate implementation instruction. Then implement communication-driven visibility and
primitive writing transitions, run focused checks and return to owner visual acceptance.
