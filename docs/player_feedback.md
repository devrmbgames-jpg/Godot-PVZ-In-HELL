# Player feedback contract

`InteractionHud` reads Health, Hunger, wallet/debt/penalties independently of debug panels. Existing challenge requirements/countdown/gaze warnings and contextual prompts retain their owning presentation services. Debug timers, conditions and tasks remain available. Disabling presentation does not mutate gameplay.

`PackageConditionView` attaches four native markings to mesh faces; they inherit physical motion and show Fragile/Heavy/Liquid plus Damaged/Opened. Existing condition billboard remains.

`O_DamageFeedback` observes committed positive DAMAGE results only, before destructive Health/package lifecycle observers. It emits `DamageFeedback`, a primitive snapshot of target identity, audience, damage type, applied amount, world position and depletion/instigator facts. There are no live Entity references; target deletion cannot invalidate the view payload. Rejected, blocked and healing results do not emit hit feedback.

`DamageFeedbackView` shows warnings for its assigned player and bounded timed world labels for packages/player-caused hits. Toxic and explosion warnings use distinct captions, colours and generated tones. Reduced motion defaults on; sounds and the whole view can be disabled. Lifetime limits, exit disconnection and label cleanup belong to the view. `debug_text()` exposes remaining timers and limits without gameplay authority.

Locked-door prompts read access eligibility without unlocking/consuming items. Scanner success retains the registration number and beep; rejection displays its reason and stops the success sound. Input/state transitions remain in existing owners.

R22 automation: 109 GUT tests / 548 assertions, strict player-feedback and gaze smokes, main headless shutdown. Native-node assertions do not establish rendered readability or audio perception. Owner QA: full scenario, resolutions/HUD overlap, rotated box readability, gamepad and sound distinction/comfort.
