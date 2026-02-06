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
