# Polish Plan (Planning Only)

Purpose: Capture feel/feedback polish ideas without touching code while the review branch is active.

## Scope
- Combat feedback and UI polish for HP changes.
- Game feel improvements (camera, timing, screen effects, audio cues).

## Non-Goals
- No code changes.
- No asset production beyond placeholders or references.
- No balance tuning for damage numbers.

## Feature: Yellow Health Bar (Recent Damage)
Description: A delayed "recent damage" bar that lags behind the real HP, then drains to the current value.

Behavior
- On damage: current HP bar drops immediately to new value.
- Yellow bar holds for a short beat, then drains smoothly to match current HP.
- On healing: yellow bar snaps up to current HP (no lag), to avoid implying recent damage.

States
- Idle: yellow bar matches current HP.
- Hold: yellow bar stays at pre-damage value for a short beat.
- Drain: yellow bar lerps down to current HP.

Tuning Parameters
- Hold time: start with 0.25-0.4s.
- Drain speed: start with 0.6-1.0s to full converge.
- Minimum drain speed: ensure it never feels "stuck" on big hits.

UX Notes
- Ensure the yellow bar sits behind the main bar and is clearly visible.
- Avoid overshoot or bouncing; this should feel weighty, not elastic.
- If multiple hits arrive during hold/drain, yellow bar should re-anchor to the new pre-damage value and restart the hold timer.

Acceptance Criteria
- Single hit shows immediate HP drop and delayed yellow drain.
- Multiple hits in quick succession still feel readable.
- Healing never leaves a trailing yellow bar.

## Feature: HP Number Scroll (In-Place Counter)
Description: HP numbers roll in place like an odometer. The number block stays fixed; only digits animate.

Behavior
- On damage: digits roll downward in place to the new value, then settle.
- On healing: digits roll upward in place to the new value, then settle.
- The container does not move. Only the digits animate.
- If multiple hits occur rapidly, the digits should blend/retarget rather than jitter.

Tuning Parameters
- Digit roll speed: fast enough to read, slow enough to perceive direction.
- Animation time: 0.12-0.2s to settle after the final value.
- Easing: quick in, gentle settle.

UX Notes
- Keep numbers legible at all times (no blur, avoid subpixel shimmer).
- Consider a faint flash tint: red for damage, green for healing.
- Consider tabular/monospace digits so width does not shift.

Acceptance Criteria
- Direction of roll is always correct.
- Numbers remain readable during animation.
- Rapid hits do not cause unreadable flicker.

## Cursor Tint (Readability)
Description: Change cursor tint to a lighter, higher-contrast value so it is easier to track.

Behavior
- Use a light tint or outline that remains visible over dark backgrounds.
- Avoid dark-on-dark combinations that reduce visibility.

Acceptance Criteria
- Cursor remains clearly visible over typical combat backgrounds.

## Game Feel Enhancements
Goal: Make actions feel punchy and reactive without overwhelming the player.

Camera
- Light camera shake on heavy hits or crits.
- Short, directional camera nudge toward the target on impact.
- Optional micro-zoom on big moments (boss skill, finisher).

Timing
- Hit stop on impactful strikes (very short, 2-6 frames).
- Input buffering should still feel responsive during brief hit stop.

Screen Effects
- Subtle screen flash or vignette on heavy hits.
- Brief sprite scale "pop" on impact (if applicable).
- Motion blur only if it does not reduce readability.

Audio/Feedback (Non-asset Planning)
- Stronger impact SFX layers on heavy hits.
- Low-frequency thump for high damage.
- Short UI tick on HP change to make the UI feel alive.

Combat Readability
- Ensure hit feedback does not mask intent telegraphs.
- Keep screen effects below the readability threshold.

Acceptance Criteria
- Heavy hits feel heavier than light hits.
- Effects are noticeable but never obscure critical UI.
- Combat feels more responsive without increasing difficulty.

## Modern 2D Pixel RPG Patterns (Observations)
UI Clarity
- Strong visual hierarchy: essential combat info is readable at a glance.
- High-contrast UI frames and outlines to separate UI from pixel backgrounds.
- Consistent iconography and status markers to reduce cognitive load.
 - Pixel-snapped UI and consistent grid alignment to keep edges crisp.
 - Background scrims or subtle panels behind text to preserve readability.

Combat Feedback
- Clear confirmation for hit, block, miss, and crit states.
- Lightweight camera and screen FX used sparingly to preserve readability.
- Subtle timing cues that make actions feel snappy without hiding turn order.
- Short, distinct audio cues for state changes (guard, break, resist, heal).

Targeting and Turn Order
- Always-visible active target indicator, distinct from hover/preview.
- Turn order clarity: current actor is unmistakable; next actor is readable at a glance.
- Confirmed action feedback (cast start, impact, result) in a consistent rhythm.

Status Communication
- Buff/debuff icons are consistent in shape and placement, with short labels on focus.
- Clear separation between temporary status (turn-based) vs persistent traits.
- Simple state priority: only the most critical status is visually emphasized.

Accessibility and Comfort
- Effects like screen shake, motion blur, and flashes are optional or adjustable.
- Contrast and legibility targets are defined for UI elements.
 - Flashing effects stay below seizure-risk thresholds.

## UX Review: Player Feedback Coverage
What feels strong in the current plan
- Immediate HP drop plus delayed yellow bar creates clear damage confirmation.
- In-place digit rolling provides a clear direction cue without moving the UI block.

Gaps and risks
- Feedback coverage for non-damage events is not defined (miss, block, guard, resist).
- No explicit options for reducing visual intensity (shake, flash, hit stop).
- Reliance on color-only cues could reduce clarity for color-blind players.
- No stated rules for prioritizing overlapping feedback (e.g., crit + low HP).

Recommendations
- Add a feedback matrix for outcomes: hit, crit, block, miss, heal, shield.
- Provide intensity sliders or toggles for shake/flash/motion effects.
- Ensure critical cues are never color-only (use icon, text, or shape as a backup).
- Define a priority order for overlapping effects and ensure it never obscures intent.
- Confirm which feedback is immediate vs delayed so results never feel ambiguous.
- Define a minimum feedback set that always fires even at low FX settings.

## UX Lens: Feedback Loop Checklist
- Immediate confirmation: player knows their input was registered.
- Impact confirmation: player knows the result (hit, miss, block, resist).
- State persistence: important changes remain visible long enough to be understood.
- Redundancy: critical outcomes are conveyed through at least two channels (e.g., visual + audio or visual + text).
- Consistency: the same outcome always produces the same primary cue.

## Additional Polish Ideas (Planning)
UI/Feedback
- Light pulse on the HP frame when taking damage, fade out quickly.
- Small tick sound on each HP change to reinforce responsiveness.
- Low-HP warning: subtle vignette or heartbeat rhythm at critical threshold.
- Selection feedback: quick brightness pulse or outline on the active target.

Combat Feel
- Slight enemy recoil or micro-stagger on confirmed hits (if animation allows).
- Damage number "pop" scale (very small) on critical hits only.
- Very short slow-motion on finishing blows (rare use only).

Readability Safeguards
- Make all flashes respect a global intensity cap.
- Keep all timing changes short and tied to hit events only.
- Target non-text UI contrast of at least 3:1 against adjacent colors.
- Avoid color-only meaning for critical state changes.
 - Keep flashing below 3 flashes per second for full-screen or high-contrast FX.

## Sequencing Plan (No Code)
- Align with UI/UX intent: confirm durations and visual priority.
- List candidate events that trigger each effect (light hit, heavy hit, crit, heal).
- Decide "budget" per effect: how often it can appear before feeling noisy.

## Risks
- Overlapping effects could reduce readability.
- Too much shake/flash can feel fatiguing.
- Timing mismatches can make the UI feel sluggish.

## Open Questions
- Which events qualify as "heavy hit" vs "light hit"?
- Should yellow bar appear on shields or only real HP?
- Do we want separate behaviors for party members vs enemies?
- Do we want player options for effect intensity (shake, flash, hit stop)?

## Design Specifications (Planning)
Purpose: Define concrete targets for implementation while keeping this doc planning-only.

HP Bars
- Yellow bar hold: 0.25-0.4s.
- Yellow bar drain: 0.6-1.0s to converge.
- Yellow bar behavior: re-anchor on new damage during hold/drain; snap to current HP on healing.
- Layering: yellow bar behind main HP bar with visible edge/outline.

HP Numbers (In-Place Counter)
- Container: fixed position; digits roll only.
- Direction: damage rolls down; healing rolls up.
- Digit width: tabular/monospace to prevent layout shifts.
- Roll settle time: 0.12-0.2s after final value.
- Rapid updates: retarget to latest value; no jitter.

Cursor
- Tint: light, high-contrast vs typical background.
- Outline: optional thin outline to preserve visibility on bright tiles.

Hit Stop
- Light hit: 0-2 frames.
- Heavy hit/crit: 3-6 frames.
- Guard/block: 1-2 frames.
- Finisher: 4-8 frames (rare use only).

Camera
- Shake amplitude: small for light hits, moderate for heavy hits, none for misses.
- Directional nudge: toward impact direction, very short duration.
- Zoom: optional micro-zoom on heavy hits; disable on low FX settings.

Screen FX
- Flash/vignette: subtle, short (<0.2s).
- Pop scale: 2-4% on impact, fast in/out.
- Flashing: never exceed 3 flashes per second for full-screen/high-contrast FX.

Audio Feedback
- HP tick: quiet UI click per change (rate-limited).
- Hit impact: layered for heavy hits (low-frequency thump + sharp transient).
- Block/guard: distinct metallic or muted thunk.

Feedback Priority (When Effects Overlap)
- Primary: outcome cue (hit/miss/block/crit).
- Secondary: magnitude cue (heavy, crit, finisher).
- Tertiary: state cue (low HP, buff/debuff).

Low-FX Mode Minimum Set
- Outcome text or icon (hit/miss/block/crit).
- HP bar immediate drop plus yellow drain.
- In-place digits roll.
- No camera shake or screen flash.

Success Metrics
- Player can identify outcome within 0.3s.
- UI remains readable during bursts of effects.
- No single effect obscures intent telegraph or target indicator.
