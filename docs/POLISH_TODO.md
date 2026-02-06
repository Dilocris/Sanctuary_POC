# Polish Plan - Implementation Status & Todo

Generated from codebase audit against `POLISH_PLAN.md`.

## Already Implemented

| Feature | Location | Notes |
|---------|----------|-------|
| Hit shake (sprite recoil) | `battle_animation_controller.gd:207` | X-axis oscillation on damage |
| Damage flash (red tint) | `battle_animation_controller.gd:310` | Brief red modulate + fade |
| Floating damage/status text | `battle_animation_controller.gd:51-108` | Damage numbers, status ticks |
| Action whip (attack lunge) | `battle_animation_controller.gd:185` | Directional lunge + return |
| Idle wiggle (active actor) | `battle_animation_controller.gd:115` | Sine-wave X sway |
| Global idle breathing | `battle_animation_controller.gd:234` | Subtle 1px drift, all actors |
| Poison tint cycle | `battle_animation_controller.gd:275` | Green self_modulate loop |
| Target outline shader | `target_cursor.gd:26-53` | Edge-detect outline on selection |
| Tween cleanup on KO | `battle_animation_controller.gd:337` | Prevents memory leaks |

## Known Code Issue (Prerequisite)

**Duplicate HP bar code** — The party HP bar is built in two places with identical logic:
- `battle_scene.gd:766-838`
- `battle_ui_manager.gd:240-299`

This must be consolidated into a single builder before implementing Yellow Bar or HP Scroll.

The placeholder `scenes/ui/hp_bar.tscn` is an empty `Control` node (work started, never completed).

## Todo List (sorted by ease of implementation)

### Trivial (< 30 min each)

- [ ] **1. Cursor tint** — Change cursor to lighter high-contrast color/outline.
  - Files: `target_cursor.gd` (outline_color uniform), `battle_menu.gd:139` (cursor ColorRect)
  - Spec: `POLISH_PLAN.md` line 213-215

- [ ] **2. Crit damage pop scale** — Larger font_size for critical hit damage floaters.
  - File: `battle_animation_controller.gd` (`create_damage_text`)
  - Spec: `POLISH_PLAN.md` line 171

### Easy (30 min - 1 hr each)

- [ ] **3. HP frame pulse on damage** — Quick modulate flash on the HP bar's StyleBox when damage lands.
  - Files: `battle_ui_manager.gd`, `battle_renderer.gd` (boss bar)
  - Spec: `POLISH_PLAN.md` line 164

- [ ] **4. Selection brightness pulse** — Brief modulate pulse on active target during selection.
  - File: `target_cursor.gd` (`_set_highlight`)
  - Spec: `POLISH_PLAN.md` line 167

- [ ] **5. Screen flash/vignette on heavy hits** — ColorRect overlay with quick alpha tween on big damage.
  - File: new overlay in `battle_scene.gd` or `battle_animation_controller.gd`
  - Spec: `POLISH_PLAN.md` lines 229-231

- [ ] **6. Sprite scale pop** — Brief 2-4% scale tween on hit targets.
  - File: `battle_animation_controller.gd`
  - Spec: `POLISH_PLAN.md` line 230

### Medium (1-2 hrs each)

- [ ] **7. Consolidate duplicate HP bar code** — Extract shared HP bar builder, populate `hp_bar.tscn`.
  - Files: `battle_scene.gd`, `battle_ui_manager.gd`, `scenes/ui/hp_bar.tscn`
  - **Prerequisite for items 9 and 10**

- [ ] **8. Camera shake on heavy hits** — Position tween on root/Camera2D node (not sprites).
  - File: `battle_animation_controller.gd` or new camera controller
  - Spec: `POLISH_PLAN.md` lines 224-226

- [ ] **9. Directional camera nudge** — Short positional nudge toward impact direction.
  - File: same as camera shake
  - Spec: `POLISH_PLAN.md` line 225

- [ ] **10. Yellow Health Bar (recent damage)** — Second ProgressBar behind main bar with hold→drain state machine.
  - Depends on: item 7 (consolidated HP bar)
  - Spec: `POLISH_PLAN.md` lines 14-40, 200-204
  - States: Idle / Hold (0.25-0.4s) / Drain (0.6-1.0s)
  - Re-anchor on new damage during hold/drain; snap on healing

- [ ] **11. HP Number Scroll (odometer)** — Replace static RichTextLabel with digit-rolling tween animation.
  - Depends on: item 7 (consolidated HP bar)
  - Spec: `POLISH_PLAN.md` lines 42-64, 206-211
  - Tabular/monospace digits, 0.12-0.2s settle, retarget on rapid hits

- [ ] **12. Hit stop** — Brief `Engine.time_scale` pause (2-6 frames) on impactful strikes.
  - File: `battle_animation_controller.gd` or `battle_scene.gd`
  - Spec: `POLISH_PLAN.md` lines 217-221
  - Must preserve input buffering during pause

- [ ] **13. Enemy micro-recoil/stagger** — Directional positional offset on confirmed hits (extends hit shake).
  - File: `battle_animation_controller.gd` (`play_hit_shake`)
  - Spec: `POLISH_PLAN.md` line 170

- [ ] **14. Low-HP warning** — Subtle red vignette or heartbeat pulse at critical HP threshold.
  - File: new overlay or HP bar tint logic
  - Spec: `POLISH_PLAN.md` line 166

- [ ] **15. Finishing blow slow-motion** — Brief `Engine.time_scale` dip on KO hits (rare use).
  - File: `battle_scene.gd` action resolution
  - Spec: `POLISH_PLAN.md` line 172

- [ ] **16. Micro-zoom on big moments** — Camera zoom tween on boss skills/finishers.
  - File: camera controller
  - Spec: `POLISH_PLAN.md` line 226

### Hard (2+ hrs each)

- [ ] **17. Floaters readability** — Limit simultaneous floaters per target, add stacking/summary, improve contrast.
  - File: `battle_animation_controller.gd` (floater management)
  - Spec: `POLISH_PLAN.md` lines 249-252

- [ ] **18. Non-damage feedback matrix** — Distinct visual cues for miss, block, guard, resist (icon + text + shape, not color-only).
  - Files: `battle_animation_controller.gd`, `battle_scene.gd`
  - Spec: `POLISH_PLAN.md` lines 148-152, 238-241

- [ ] **19. Audio feedback hooks** — AudioStreamPlayer wiring for HP tick, impact layers, guard SFX (placeholder sounds).
  - Files: `battle_animation_controller.gd`, `battle_scene.gd`
  - Spec: `POLISH_PLAN.md` lines 233-236

- [ ] **20. Low-FX accessibility mode** — Settings toggle disabling shake/flash/vignette; minimum feedback set preserved.
  - Files: new settings, conditional paths in animation controller
  - Spec: `POLISH_PLAN.md` lines 254-258

- [ ] **21. Full-screen event timing system** — Queue manager for phase changes, limit breaks, overlapping full-screen events.
  - Files: `battle_scene.gd`, `battle_ui_manager.gd`
  - Spec: `POLISH_PLAN.md` lines 243-247
