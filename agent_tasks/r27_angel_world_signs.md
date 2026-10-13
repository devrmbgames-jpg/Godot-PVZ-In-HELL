# R27.3 — таблички ангела в мировом пространстве

Status: **IN_PROGRESS**

Parent: [R27](r27_qa_followup.md).

## Task state

### Goal / acceptance

- Angel service cues appear on an authored3D sign object in front of the NPC with Label3D text.
- Sign text communicates the current recipient's request; player discovers it visually.
- Angel does not open the normal dialogue UI to display signs while frozen under observation.
- Preserve actual observation/freeze, parcel interaction/outcomes and typed dialogue/gameplay actions.
- Sign lifecycle follows participant/role/scene lifetime; no orphan signs after reset/transition/death.
- Native tests verify cue text/placement/lifetime and absence of normal sign-dialogue request.

### Current

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

### Validation

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
Exact-SHA review NOT_RUN until this coherent checkpoint is committed.

### Owner QA / blockers

Owner visual readability and placement acceptance remains open.

### Next

Commit the tested checkpoint and review its immutable SHA; continue physical passing and test rooms.
