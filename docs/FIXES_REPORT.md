# Fixes Report

## Fix 001: SettingsMenu class_name not found in battle_scene.gd

**Error:**
```
res://scripts/battle_scene.gd:110 - Parse Error: Could not find type "SettingsMenu" in the current scope.
res://scripts/battle_scene.gd:164 - Parse Error: Identifier "SettingsMenu" not declared in the current scope.
```

**Root cause:**
Used `SettingsMenu` as a bare type reference (via `class_name`) in `battle_scene.gd` for both the variable declaration (`var settings_menu: SettingsMenu`) and instantiation (`SettingsMenu.new()`). Godot 4's `class_name` registration is load-order dependent — if the engine hasn't parsed `settings_menu.gd` before `battle_scene.gd`, the global name isn't available yet.

**Fix:**
- Added explicit `const SettingsMenuClass = preload("res://scripts/ui/settings_menu.gd")` at the top of `battle_scene.gd` (matching the existing pattern: `BattleMenuScene`, `TargetCursorScene`, `ActorDataScript`, etc.)
- Changed type annotation to `var settings_menu: Node` (duck-typed, since the preloaded const isn't a registered type for annotations)
- Changed instantiation to `SettingsMenuClass.new()`

**Lesson:**
In this codebase, always use `const XClass = preload(...)` + `XClass.new()` for programmatically created scripts. Never rely on bare `class_name` references across files — Godot's parse order isn't guaranteed.

---

## Fix 002: OdometerLabel digit strips not clipped — numbers cascading across screen

**Symptoms:**
- Massive columns of stacked numbers (0-9 for each digit position) visible below boss HP bar and all party HP bars
- Numbers overflow past the party panel and off the bottom of the screen
- Pattern: "01", "2311", "3422", "4533"... (each digit column's full 0-9 strip visible)

**Root cause (3 overlapping issues):**
1. `clip_children = CLIP_CHILDREN_AND_DRAW` on the inner `_clip_container` (a plain Control) was not reliably clipping its children. Likely a Godot 4 rendering quirk where clipping on a non-drawing Control node doesn't establish a clip rect.
2. The AnimatedHealthBar itself had no `clip_children`, so even if the OdometerLabel partially clipped, the overflow escaped into the scene.
3. Odometer sizes were hardcoded (`digit_height=14`, `font_size=12`) regardless of bar height. Party HP bars are 12px tall, so the 14px OdometerLabel overflowed the bar even without the digit strip issue.

**Fix (defense-in-depth):**
- Added `clip_children = Control.CLIP_CHILDREN_AND_DRAW` on **OdometerLabel itself** (`odometer_label.gd:_ready()`)
- Added `clip_children = Control.CLIP_CHILDREN_AND_DRAW` on **AnimatedHealthBar itself** (`animated_health_bar.gd:_ready()`)
- Added `clip_children = Control.CLIP_CHILDREN_AND_DRAW` on the **HBoxContainer** (`_hp_container`) that holds the odometer
- Made odometer sizes **dynamic based on `bar_size.y`**:
  - `digit_height = min(bar_size.y, 16)` — scales to fit bar, caps at 16
  - `font_size = max(8, digit_height - 3)`
  - `digit_width = max(6, digit_height * 0.55)`
  - Separator/max label font = `max(7, digit_height - 4)`

**Lesson:**
- Never rely on a single `clip_children` on an inner Control — add it at multiple levels (the control itself, its container, and the parent widget)
- Always size text/digit elements relative to their container, never hardcode sizes that exceed the parent dimensions
- When creating UI programmatically, test with the actual bar sizes (12px, 8px, 26px) — small bars expose overflow bugs that look fine on larger ones

---

## Fix 003: Odometer still overflowing — disabled in favor of static text

**Symptoms:**
Despite clip_children fixes (Fix 002), odometer digits still stacked visually. Multiple levels of clipping did not reliably contain the digit strips in Godot 4.6.

**Decision:**
Disabled odometer (`use_odometer = false`) on all health bars (party HP + boss HP). Reverted to static text display (`[b]HP[/b]/MaxHP` via RichTextLabel). The odometer implementation needs deeper investigation into Godot 4's clip_children behavior before re-enabling.

**Additional UI fixes in this pass:**
- Settings menu type annotations changed from bare `class_name` to base types (`Node`, `RefCounted`) to prevent parse errors
- Item action commented out from battle menu (system not implemented, was clipping off screen)
- LB bars right-aligned via expand spacer so they form a consistent column
- Added "F1: Settings" hint label at bottom-right corner

**Lesson:**
- Prefer simple, proven UI patterns (static text) over complex animated ones (odometer) until the animation system is fully debugged
- Apply the `const XClass = preload()` pattern even to type annotations in new files — don't mix bare class_names and preloads

---

## Fix 004: Settings menu doesn't restore battle menu on close

**Symptoms:**
After opening the settings menu with F1 and closing it, the battle action menu (Attack/Skill/Defend) disappears and the player cannot take any action.

**Root cause:**
In `settings_menu.gd:close()`, the code checked `_battle_manager.battle_state.get("state", "")` for `"PLAYER_TURN"`. But `state` is a direct variable on `battle_scene.gd` (`var state = "BATTLE_START"`), NOT stored inside the `battle_state` dictionary. The `.get("state", "")` always returned `""`, so the condition `state == "PLAYER_TURN"` was never true, and `battle_menu.set_enabled(true)` was never called.

**Fix:**
Changed `_battle_manager.battle_state.get("state", "")` to `_battle_scene.state` — accessing the var directly on the scene node.

**Lesson:**
- Know where each piece of state lives. `battle_state` is a dictionary on `BattleManager` with party/enemies/flags. The turn phase `state` is a plain var on `battle_scene.gd`.
- When bridging between controllers and the main scene, always verify the data path — don't assume a dict key exists just because the concept sounds right.

---

## Fix 005: Lower UI too small, HP/MP text unreadable, LB bar misaligned

**Symptoms:**
- HP and MP text cramped inside bars (13px font in 12px bar), unreadable
- Only 3 actions visible before overflow in battle menu
- LB bar right-aligned with no label — purpose unclear

**Changes:**
- Moved `LOWER_UI_TOP` from 520 to 492 (28px more vertical space)
- Increased `HP_BAR_HEIGHT` from 12 to 16 and `MP_BAR_HEIGHT` from 8 to 10
- Made `animated_health_bar.gd` static text font_size dynamic: `mini(bar_size.y - 1, 14)`
- Updated battle menu `.tscn` panel to match new Y offset (492)
- LB bar: removed expand spacer, added "LB" label, left-aligned in row
- Integrated Silkscreen pixel font (SIL OFL) across all UI labels

**Lesson:**
- Font sizes must be proportional to container height — never hardcode a font_size larger than the bar it sits in
- Lower UI panels and menu panels must share the same LOWER_UI_TOP constant to stay aligned

---

## Battle Polish Sprint (2026-02-05)

### Phase 1 — Text & Config

**Changes:**
- Kairus idle spritesheet scale reduced from `0.45` to `0.40` (better proportion with party)
- Y-based `z_index` on all actor/boss nodes (`z_index = int(position.y)`) for correct depth sorting
- Verified idle sway is disabled (stepped 2-keyframe idle only)
- Applied Silkscreen pixel font to battle menu labels (action items, actor name, description panel)
- Per-character Limit Break descriptions (was generic "Limit Break" for all)
- Resource short names + consistent skill descriptions with "Cost. Effect." format

### Phase 2 — UI Layout

**Changes:**
- **Frame bleed fix:** Replaced `hframes/vframes` with `region_rect` for spritesheet animation — integer division frame sizes (`tex_w / hframes`) prevent fractional pixel bleed
- HP bar height `16→20`, MP bar height `10→14`, `BAR_WIDTH = 130`
- Bar background contrast increased: `Color(0.12, 0.12, 0.12)` → `Color(0.22, 0.22, 0.25)`
- Party panel: replaced HBoxContainer layout with fixed-position Control columns (Name | Bars | Resource | LB) with 1px vertical separators
- LB bar flash effect: pulse tween between blue tones when gauge reaches 100%
- Battle menu panel widened to 220px; description panel full height with autowrap
- Actor name separator line + color in battle menu
- Fixed 2x8 resource dot grid (`resource_dot_grid.gd`) — `dot_size=8`, `dot_spacing=2`, `fixed_columns=8`
- LB bars in own aligned column (fixed x-offset at 296/316)

**Bug Fixes:**
- LB percentage number scaled up: font_size `9→11`, bar height `12→14px`
- Active character name overflow: removed font size scaling in party panel (color-only styling), added `clip_text = true`, added subtle row highlight (`Color(1.0, 0.9, 0.4, 0.08)` background tint)

### Phase 3 — Game Logic

**Task 9: Fire Imbue skip Ki drain on activation turn**
- `action_resolver.gd`: sets `flags["fire_imbue_skip_drain"] = true` when toggling Fire Imbue ON
- `status_processor.gd`: checks flag before Ki drain, clears it if true — skips exactly one drain cycle

**Task 10: Burn DOT**
- `status_effect_ids.gd`: added `const BURN := "BURN"`
- `status_effect_factory.gd`: added `burn(turns=2, damage=8)` with `DOT + ELEMENTAL + CLEANSABLE` tags
- `action_resolver.gd`: applies Burn in `execute_basic_attack()` and Flurry (first hit) when attacker has `FIRE_IMBUE` and target lacks `BURN`
- Existing DOT processor handles tick automatically (no changes needed)

**Task 5: Fireball game feel fix**
- Changed Fireball payload to include `multi_target_damage` array with per-target `{target_id, damage}` entries
- Added `multi_target_damage` handler in `battle_scene.gd:_on_action_executed()` — spawns damage numbers, hit shake, and game feel per target
- Same pattern applied to Venom Strike for consistency

### Phase 4 — Animation System

**Task 11: Attack spritesheet support**
- `battle_renderer.gd`: added `ATTACK_SPRITESHEETS` config (kairus: 1024x1024, hframes=4, vframes=3, fps=14, impact_frame=8)
- `battle_animation_controller.gd`: added full attack animation system:
  - Storage: `_attack_configs`, `_idle_textures`, `_idle_configs`, `_attack_playing`
  - `register_attack_spritesheet()` / `register_idle_texture()` / `has_attack_animation()`
  - `play_attack_animation(actor_id, on_impact, on_complete)`: pauses idle timer, swaps texture, plays frames via region_rect with bottom-anchor offset, fires `on_impact` at configured `impact_frame`, restores idle on completion

**Task 12: Attack animation sync with damage**
- `battle_scene.gd`: extracted damage/heal/buff visuals into `_show_action_visuals(payload)`
- If attacker has attack animation + payload has damage: plays attack anim, fires `_show_action_visuals()` at impact frame
- Otherwise: falls back to existing `play_action_whip()` with immediate visuals

**Lesson:**
- Timer.set_meta("frame", N) pattern works well for mutable state in GDScript closures (closures can't mutate captured local vars)
- Attack animation texture swap + idle restoration requires storing both idle and attack texture/config references separately
- Impact frame callbacks let damage visuals sync precisely to the animation keyframe
