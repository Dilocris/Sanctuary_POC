# Polish Plan - Implementation Status & Todo

Generated from codebase audit against `POLISH_PLAN.md`. Updated after Battle Polish Sprint (2026-02-05).

## Already Implemented

| Feature | Location | Status |
|---------|----------|--------|
| Hit shake (sprite recoil) | `battle_animation_controller.gd:220` | Working — now directional recoil |
| Damage flash (red tint) | `battle_animation_controller.gd:310` | Working |
| Floating damage/status text | `battle_animation_controller.gd:51-108` | Working — heavy hits get 44px + pop-in scale |
| Action whip (attack lunge) | `battle_animation_controller.gd:198` | Working |
| Idle wiggle (active actor) | `battle_animation_controller.gd:115` | Working |
| Global idle breathing | `battle_animation_controller.gd:260` | Working |
| Poison tint cycle | `battle_animation_controller.gd:290` | Working |
| Tween cleanup on KO | `battle_animation_controller.gd:360` | Working |
| Cursor tint + dual outline | `target_cursor.gd:61-111` | Working |
| Selection brightness pulse | `target_cursor.gd:34-59` | Working |
| Yellow Health Bar | `animated_health_bar.gd` | Working — hold/drain state machine via `battle_ui_manager.gd` |
| HP Number Scroll (odometer) | `odometer_label.gd` | Working — enabled by default |
| Camera shake | `game_feel_controller.gd` | Working — light/heavy amplitude |
| Hit stop | `game_feel_controller.gd` | Working — `Engine.time_scale` freeze |
| Screen flash/vignette | `game_feel_controller.gd` | Working — CanvasLayer overlay |
| Sprite scale pop | `game_feel_controller.gd` | Working — scale tween on heavy hits |
| Crit hit effects | `game_feel_controller.gd` | Working — amplified shake + flash + stop + pop |
| Phase transition FX | `game_feel_controller.gd` | Working — strong shake + red flash |
| Limit break FX | `game_feel_controller.gd` | Working — gold flash + hit stop |
| Resource dot grid | `resource_dot_grid.gd` | Working — 2-row dot display for Ki, SD, etc. |
| **Heavy damage pop scale** | `battle_animation_controller.gd:85-107` | **NEW** — 44px font + pop-in scale for hits >= 50 dmg |
| **HP frame pulse on damage** | `animated_health_bar.gd:_pulse_on_damage` | **NEW** — quick modulate flash on HP bar when hit |
| **Odometer enabled** | `animated_health_bar.gd`, `battle_ui_manager.gd` | **NEW** — `use_odometer = true` for HP and MP bars |
| **Directional camera nudge** | `game_feel_controller.gd:nudge_camera` | **NEW** — positional push toward impact, scales with damage |
| **Directional hit recoil** | `battle_animation_controller.gd:play_hit_shake` | **NEW** — party recoils left, enemies recoil right, includes Y offset |
| **Low-HP warning** | `animated_health_bar.gd:_check_low_hp` | **NEW** — red bar + heartbeat pulse at <= 25% HP |
| **Finishing blow slow-mo** | `game_feel_controller.gd:on_finishing_blow` | **NEW** — 0.3x time scale + flash + shake on KO hits |
| **Duplicate HP bar fix** | `battle_scene.gd:_update_status_label` | **FIXED** — delegates to `ui_manager.update_party_status()` |
| **Frame bleed fix** | `battle_renderer.gd` | **NEW** — region_rect with integer-division frame sizes replaces hframes/vframes |
| **Fixed-column party panel** | `battle_ui_manager.gd` | **NEW** — pixel-precise column layout with 1px separators |
| **LB bar flash** | `battle_ui_manager.gd` | **NEW** — pulse tween between blue tones at 100% gauge |
| **Row highlight (active)** | `battle_ui_manager.gd` | **NEW** — subtle background tint instead of font size scaling |
| **Resource dot grid** | `resource_dot_grid.gd` | **NEW** — fixed 2x8 layout, dot_size=8, dot_spacing=2 |
| **Pixel font everywhere** | `battle_menu.gd`, `battle_scene.gd` | **NEW** — Silkscreen applied to all menu labels |
| **Fire Imbue skip drain** | `action_resolver.gd`, `status_processor.gd` | **NEW** — no Ki drain on activation turn |
| **Burn DOT** | `status_effect_factory.gd`, `action_resolver.gd` | **NEW** — Fire Imbue attacks apply Burn (2 turns, 8 dmg) |
| **Multi-target game feel** | `battle_scene.gd`, `action_resolver.gd` | **NEW** — per-target damage numbers + shake for Fireball/Venom Strike |
| **Attack spritesheet** | `battle_renderer.gd`, `battle_animation_controller.gd` | **NEW** — Kairus attack anim (4x3, 14fps) with impact callback |
| **Attack sync** | `battle_scene.gd`, `battle_animation_controller.gd` | **NEW** — damage visuals fire at impact frame, extracted to `_show_action_visuals()` |

## Resolved: Duplicate HP Bar Code

The old `_update_status_label` in `battle_scene.gd` has been replaced. It now delegates to:
- `ui_manager.update_party_status()` (AnimatedHealthBar + ResourceDotGrid)
- `ui_manager.update_boss_status()`
- `ui_manager.update_status_effects_text()`

Boss HP bar is wired to `ui_manager` via `set_boss_hp_bar()` in `_ready()`.

## Remaining Todo (sorted by ease)

### Medium

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
