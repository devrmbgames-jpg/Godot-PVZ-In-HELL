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

### Current

Source `d0568a32b4f80ab02a9ab8ab0d84babe341a91be`.
Existing weeping_angel variant_a/b dialogue and district NPC authored scene are the owner surface.
Implementation/testing/review NOT_RUN; stable sign is native editable prefab, not generated scene text.

### Validation

NOT_RUN for this milestone; native presentation/lifetime coverage is required.

### Owner QA / blockers

Owner visual readability and placement acceptance remains open.

### Next

Trace existing sign cues/dialogue request boundary and add world-sign presentation through native scene authoring.
