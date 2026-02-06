# Polish Plan - Implementation Status & Todo

Generated from codebase audit against `POLISH_PLAN.md`. Updated after `66499ae` upstream merge.

## Already Implemented

| Feature | Location | Status |
|---------|----------|--------|
| Hit shake (sprite recoil) | `battle_animation_controller.gd:207` | Working |
| Damage flash (red tint) | `battle_animation_controller.gd:310` | Working |
| Floating damage/status text | `battle_animation_controller.gd:51-108` | Working |
| Action whip (attack lunge) | `battle_animation_controller.gd:185` | Working |
| Idle wiggle (active actor) | `battle_animation_controller.gd:115` | Working |
| Global idle breathing | `battle_animation_controller.gd:234` | Working |
| Poison tint cycle | `battle_animation_controller.gd:275` | Working |
| Tween cleanup on KO | `battle_animation_controller.gd:337` | Working |
| **Cursor tint + dual outline** | `target_cursor.gd:61-111` | **NEW** — High-contrast dual outline shader (bright outer + dark inner) |
| **Selection brightness pulse** | `target_cursor.gd:34-59` | **NEW** — Sine-wave pulse on shader `pulse_alpha` uniform |
| **Yellow Health Bar** | `animated_health_bar.gd` | **NEW** — Hold/drain state machine, integrated in `battle_ui_manager.gd` |
| **HP Number Scroll (odometer)** | `odometer_label.gd` | **NEW** — Digit-rolling animation (disabled by default: `use_odometer = false`) |
| **Camera shake** | `game_feel_controller.gd:94-116` | **NEW** — Light/heavy amplitude, decay-based random offsets |
| **Hit stop** | `game_feel_controller.gd:130-143` | **NEW** — `Engine.time_scale = 0.0` with process-independent timer |
| **Screen flash/vignette** | `game_feel_controller.gd:120-126` | **NEW** — CanvasLayer overlay with alpha tween |
| **Sprite scale pop** | `game_feel_controller.gd:147-157` | **NEW** — Scale tween on heavy hits |
| **Crit hit effects** | `game_feel_controller.gd:161-168` | **NEW** — Amplified shake + flash + stop + pop |
| **Phase transition FX** | `game_feel_controller.gd:172-174` | **NEW** — Strong shake + red flash |
| **Limit break FX** | `game_feel_controller.gd:178-180` | **NEW** — Gold flash + hit stop |
| **Resource dot grid** | `resource_dot_grid.gd` | **NEW** — 2-row dot display for Ki, SD, etc. |

## Critical Bug: Duplicate HP Bar Code

`battle_scene.gd:777-838` (`_update_status_label`) still rebuilds the party panel using **raw ProgressBar** + static RichTextLabel on every status update. This code path:
- Bypasses `AnimatedHealthBar` (no yellow bar visible)
- Bypasses `OdometerLabel` (no digit rolling)
- Recreates all UI nodes from scratch each frame (wasteful)

Meanwhile `battle_ui_manager.gd:340-385` correctly uses `AnimatedHealthBar` + `ResourceDotGrid`.

**If `_update_status_label` is the active code path, the yellow bar and odometer features are dead code.**

This is the #1 blocker. The old code in `battle_scene.gd` must be replaced with calls to the new `AnimatedHealthBar.set_hp()` via `battle_ui_manager`.

The placeholder `scenes/ui/hp_bar.tscn` is still an empty `Control` node.

## Remaining Todo (sorted by ease)

### Trivial

- [ ] **1. Crit damage pop scale** — Larger font_size for critical hit damage floaters.
  - File: `battle_animation_controller.gd` (`create_damage_text`)
  - Currently all damage text is 32px regardless of crit status
  - Spec: `POLISH_PLAN.md` line 171

### Easy

- [ ] **2. HP frame pulse on damage** — Quick modulate flash on the HP bar container when damage lands.
  - File: `animated_health_bar.gd` (add modulate tween in `_on_damage`)
  - Spec: `POLISH_PLAN.md` line 164

- [ ] **3. Enable odometer by default** — `animated_health_bar.gd:18` has `use_odometer = false`. Flip to `true` or expose per-bar toggle.
  - Verify readability at current digit_width/height before enabling

### Medium

- [ ] **4. Fix duplicate HP bar code** — Replace `battle_scene.gd:777-838` with delegation to `battle_ui_manager.update_party_status()` using `AnimatedHealthBar.set_hp()`.
  - This unblocks yellow bar + odometer for real gameplay
  - **Highest priority item**

- [ ] **5. Directional camera nudge** — Short positional nudge toward impact direction (not just random shake).
  - File: `game_feel_controller.gd` — extend `shake_camera` or add `nudge_camera(direction)`
  - Spec: `POLISH_PLAN.md` line 225

- [ ] **6. Enemy micro-recoil/stagger** — Directional positional offset on confirmed hits (extends current hit shake).
  - File: `battle_animation_controller.gd` (`play_hit_shake`) — add direction parameter
  - Spec: `POLISH_PLAN.md` line 170

- [ ] **7. Low-HP warning** — Subtle red vignette or heartbeat pulse at critical HP threshold.
  - File: `animated_health_bar.gd` (`set_main_color` exists but not auto-triggered on low HP)
  - Spec: `POLISH_PLAN.md` line 166

- [ ] **8. Finishing blow slow-motion** — Brief `Engine.time_scale` dip on KO hits (rare use).
  - File: `game_feel_controller.gd` — add `on_finishing_blow()` method
  - Spec: `POLISH_PLAN.md` line 172

- [ ] **9. Micro-zoom on big moments** — Camera zoom tween on boss skills/finishers.
  - Requires Camera2D node (currently not in scene tree)
  - Spec: `POLISH_PLAN.md` line 226

### Hard

- [ ] **10. Floaters readability** — Limit simultaneous floaters per target, add stacking/summary, improve contrast.
  - File: `battle_animation_controller.gd` — needs per-target floater tracking
  - Spec: `POLISH_PLAN.md` lines 249-252

- [ ] **11. Non-damage feedback matrix** — Distinct visual cues for miss, block, guard, resist (icon + text + shape, not color-only).
  - Files: `battle_animation_controller.gd`, `battle_scene.gd`
  - Spec: `POLISH_PLAN.md` lines 148-152, 238-241

- [ ] **12. Audio feedback hooks** — AudioStreamPlayer wiring for HP tick, impact layers, guard SFX (placeholder sounds).
  - Files: `battle_animation_controller.gd`, `battle_scene.gd`
  - Spec: `POLISH_PLAN.md` lines 233-236

- [ ] **13. Low-FX accessibility mode** — UI toggle for disabling shake/flash/vignette; keep minimum feedback set.
  - `GameFeelController` already has per-feature `_enabled` bools — needs player-facing settings UI
  - Spec: `POLISH_PLAN.md` lines 254-258

- [ ] **14. Full-screen event timing system** — Queue manager for phase changes, limit breaks, overlapping full-screen events.
  - Files: `battle_scene.gd`, `battle_ui_manager.gd`
  - Spec: `POLISH_PLAN.md` lines 243-247
