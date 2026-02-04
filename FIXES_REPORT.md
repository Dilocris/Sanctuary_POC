# Sanctuary POC - Fixes Applied Report

**Date:** 2026-02-03
**Branch:** code-review/comprehensive-review

---

## Summary

This report documents all fixes applied based on the CODE_REVIEW.md findings. All critical (P0), high-priority (P1), and medium-priority (P2) issues have been addressed. Most P3 issues have also been resolved.

---

## Completed Fixes

### P0 - Critical Bug Fixes

#### 1. Duplicate Phase Transition Logic (FIXED)
**File:** [ai_controller.gd](scripts/ai_controller.gd)

- **Issue:** Phase transitions were calculated in both `BattleManager._check_boss_phase_transition()` and `AiController._update_phase()`, risking state desync.
- **Fix:** Removed `_update_phase()` function and its call from `get_next_action()`. Phase transitions now only occur through `BattleManager` which emits the `phase_changed` signal.

#### 2. Incorrect "Highest Threat" Logic (FIXED)
**File:** [ai_controller.gd:89-108](scripts/ai_controller.gd#L89-L108)

- **Issue:** `_select_highest_threat()` returned Ludwig when he had Guard Stance (opposite of intended behavior).
- **Fix:** Rewrote logic to skip Ludwig in threat calculation when he has Guard Stance, then continue with normal threat calculation. Added fallback to Ludwig if no other targets are found.

#### 3. Inconsistent BLESS Casing (FIXED)
**File:** [status_effect_ids.gd:14](scripts/status_effect_ids.gd#L14)

- **Issue:** `const BLESS := "bless"` used lowercase while all other constants used ALL_CAPS.
- **Fix:** Changed to `const BLESS := "BLESS"` for consistency.

---

### P1 - High Priority Fixes

#### 4. Null Safety in Damage Calculation (FIXED)
**File:** [damage_calculator.gd:6-12](scripts/damage_calculator.gd#L6-L12)

- **Issue:** `calculate_physical_damage()` could crash if passed null attacker/defender.
- **Fix:** Added null guard at function start: `if attacker == null or defender == null: return 0`

#### 5. Memory Leak - Orphan Tweens (FIXED)
**File:** [battle_scene.gd](scripts/battle_scene.gd)

- **Issue:** Tweens continued running after character KO or battle end.
- **Fix:**
  - Added `_cleanup_actor_tweens(actor_id)` function to properly kill and clean up all tween types
  - Called cleanup when character is KO'd (detected in `_flash_damage_tint`)
  - Called cleanup for all actors when battle ends (in `_on_battle_ended`)

---

### P2 - Medium Priority Fixes

#### 6. O(n) Actor Lookups Optimized (FIXED)
**File:** [battle_manager.gd](scripts/battle_manager.gd)

- **Issue:** `get_actor_by_id()` iterated through arrays on every call (30+ times per action).
- **Fix:**
  - Added `_actor_lookup: Dictionary` cache
  - Added `_build_actor_lookup()` called in `setup_state()`
  - Simplified `get_actor_by_id()` to O(1) dictionary lookup

#### 7. Magic Numbers Replaced with Constants (FIXED)
**Files:** [damage_calculator.gd](scripts/damage_calculator.gd), [battle_manager.gd](scripts/battle_manager.gd)

- **Issue:** Multiple unexplained numeric values throughout code.
- **Fix:** Added descriptive constants:

**damage_calculator.gd:**
```gdscript
const GUARD_STANCE_DEF_MULTIPLIER := 1.5
const MAGE_ARMOR_DEF_MULTIPLIER := 1.5
const GUARD_STANCE_DAMAGE_REDUCTION := 0.5
const DEFENSE_FACTOR := 0.5
const VARIANCE_MIN := 0.90
const VARIANCE_MAX := 1.10
const CRIT_MULTIPLIER := 2.0
```

**battle_manager.gd:**
```gdscript
const STUNNING_STRIKE_PROC_CHANCE := 0.5
const SHIELD_BASH_STUN_CHANCE := 0.4
const DRAGONFIRE_CHARM_CHANCE := 0.7
const RIPOSTE_PROC_CHANCE := 0.5
```

---

### P3 - Low Priority Fixes

#### 8. Unused Code Removed (FIXED)
**Files:** [action_factory.gd](scripts/action_factory.gd), [action_ids.gd](scripts/action_ids.gd)

- Removed `ninos_inspire_defense()` function from action_factory.gd
- Removed `NINOS_INSPIRE_DEFENSE` constant from action_ids.gd
- Removed `CAT_MAGIC_MISSILE` constant from action_ids.gd

#### 9. Print Statements Removed (FIXED)
**Files:** [battle_scene.gd](scripts/battle_scene.gd), [target_cursor.gd](scripts/ui/target_cursor.gd)

- Removed debug print statements from production code
- Converted `_print_turn_order()` to a no-op with comment

#### 10. Excessive Whitespace Reduced (FIXED)
**File:** [battle_scene.gd](scripts/battle_scene.gd)

- Reduced excessive blank lines between functions (from 15+ to standard 2)

#### 11. Typo Fixed: BOS_GREAXE_SLAM (FIXED)
**Files:** [action_ids.gd](scripts/action_ids.gd), [action_factory.gd](scripts/action_factory.gd), [battle_manager.gd](scripts/battle_manager.gd)

- Renamed `BOS_GREAXE_SLAM` to `BOS_GREATAXE_SLAM`
- Updated all references across codebase

---

## God Class Refactoring (In Progress)

Architectural refactoring to split god classes into focused, single-responsibility components.

### Phase 1: BattleAnimationController (COMPLETE)
**File:** [battle_animation_controller.gd](scripts/battle/battle_animation_controller.gd)

Extracted ~280 lines of animation logic from `battle_scene.gd`:
- Tween management: idle wiggle, action whip, hit shake, damage flash
- Floating text: damage numbers, status tick text
- Visual effects: poison tint, global idle breathing
- Tween cleanup for KO'd actors and battle end

### Phase 2: BattleUIManager (COMPLETE)
**File:** [battle_ui_manager.gd](scripts/battle/battle_ui_manager.gd)

Extracted ~430 lines of UI logic from `battle_scene.gd`:
- Debug UI: panel, log, toggle button
- Game UI: party status, turn order, combat log, status effects
- Overlays: phase transition, limit break animations
- Enemy intent display

### Phase 3: BattleRenderer (COMPLETE)
**File:** [battle_renderer.gd](scripts/battle/battle_renderer.gd)

Extracted ~250 lines of visual creation logic from `battle_scene.gd`:
- Character/Boss visual creation with sprites, name labels
- Boss HP bar creation with styling
- Background sprite setup
- Position constants (HERO_POSITIONS, BOSS_POSITION)
- Actor dictionary management (sprites, nodes, positions, modulates)

### Phase 6: ActionResolver (COMPLETE)
**File:** [action_resolver.gd](scripts/battle/action_resolver.gd)

Extracted ~450 lines of action resolution logic from `battle_manager.gd`:
- `_resolve_action` action switch and outcome results
- `execute_basic_attack` and `_try_riposte`
- `_apply_damage_with_limit` (limit gain + phase transition hookup)
- `BattleManager` now delegates via thin wrappers

### Phase 7: TurnManager + StatusProcessor (COMPLETE)
**Files:** [turn_manager.gd](scripts/battle/turn_manager.gd), [status_processor.gd](scripts/battle/status_processor.gd)

Extracted ~220 lines from `battle_manager.gd`:
- Turn order calculation and round flow (`calculate_turn_order`, `start_round`, `advance_turn`)
- End-of-turn status ticking and expiration (`process_end_of_turn_effects`)
- `BattleManager` delegates to new managers via thin wrappers

### Phase 4: Character Data Resources (COMPLETE)
**Files:** [actor_data.gd](scripts/resources/actor_data.gd), `data/actors/*.tres`

Converted party/boss stats into data resources:
- Added `ActorData` resource schema
- Added actor resource files for Kairus, Ludwig, Ninos, Catraca, and Marcus
- `battle_scene.gd` now loads actor resources and builds actors from data

### Phase 5: Action Data Resources (COMPLETE)
**Files:** [action_data.gd](scripts/resources/action_data.gd), `data/actions/*.tres`

Converted action dictionaries into data resources:
- Added `ActionData` resource schema
- Added action resource files for all action ids
- `ActionFactory` now builds actions from data resources

---

## Post-Refactor Error Analysis (2026-02-03)

### Errors Observed
- **Parse Error:** `get()` called with 2 args in Godot 4.6 (e.g., `dict.get(key, default)`).
- **Read-only mutation:** `Character._consume_resource` when mutating dictionaries from `.tres`.
- **Load failures:** actors not spawning when resource checks rejected data.
- **Missing helper:** `_get_prop()` referenced after removal.

### Root Causes
- Godot 4.6 resolves `get()` to `Object.get()` (1-arg) in contexts that look like object calls.
- `.tres` resource data is immutable; runtime logic must clone before mutation.
- Refactor introduced helper drift and inconsistent access patterns.
- Resource validation was overly strict, leading to empty party/enemy arrays.

### Fix Strategy (Elegant + Durable)
- **Centralize cloning:** `DataClone.resource_to_dict()` and `DataClone.dict/array` for all resource data.
- **Unified defaults:** use `dict_get()` helpers instead of `Dictionary.get(key, default)`.
- **Single data ingress:** convert resource → dictionary once, then use only dictionaries in runtime.
- **Safe fallbacks:** if resource data missing, fallback to legacy data to keep game bootable.
- **Refactor hygiene:** run a helper-usage sweep after each extraction phase.

### Update: ActorData Resource Load Failures (2026-02-03)
**Symptoms from logs:**
- `Cannot get class 'ActorData'`
- `Parse Error: Can't create sub resource of type 'ActorData'`
- Load failures for `res://data/actors/*.tres`, followed by legacy fallback.

**What we tried:**
- Rewrote `.tres` files as UTF-8 (initial PowerShell output was UTF-16).
- Switched to `ResourceLoader.load(..., CACHE_MODE_IGNORE)` to avoid cache issues.
- Used `type="ActorData"` in `.tres` (failed due to class resolution errors).

**Current understanding:**
- Godot expects custom resource classes to load as `type="Resource"` with `script_class="ActorData"` and an `ext_resource` script reference.
- Using `type="ActorData"` requires the class to be registered globally before load, which is failing here.

**Previous fix attempted:**
- Rewrote actor `.tres` files as **UTF-8** with:
  - `type="Resource"`
  - `script_class="ActorData"`
  - `ext_resource` pointing to `res://scripts/resources/actor_data.gd`

### Resolution: Missing Script Assignment (2026-02-03) ✅ FIXED

**Root Cause Identified:**
The `.tres` files were missing the critical `script = ExtResource("1")` property in the `[resource]` section. While the header contained `script_class="ActorData"` and the `ext_resource` was defined, the actual script binding was never applied to the resource instance.

**Incorrect format (before):**
```
[resource]
id = "kairus"
...
```

**Correct format (after):**
```
[resource]
script = ExtResource("1")
id = "kairus"
...
```

**Fix Applied:**
- Added `script = ExtResource("1")` to all 5 actor `.tres` files
- Added `script = ExtResource("1")` to all 30 action `.tres` files

**Result:** Resources now load with correct script binding. `data.get_script() == ActorDataScript` returns `true`, enabling proper typed resource access without legacy fallback.

**Note on line endings:**
- Git reported CRLF → LF normalization warnings for actor `.tres` files:
  - `data/actors/catraca.tres`
  - `data/actors/kairus.tres`
  - `data/actors/ludwig.tres`
  - `data/actors/marcus_gelt.tres`
  - `data/actors/ninos.tres`

### Phase 8: Remaining (Reprioritized)

| Priority | Phase | Component | Notes |
|----------|-------|-----------|-------|
| LOW | 8 | Boss AI Resources | Phase/rotation config in .tres |

---

## Remaining Items (Deferred)

The following items require additional architectural work:

### Code Organization (P3)

1. **Missing `@onready` for Node References** - Many UI nodes are manually assigned. Consider using scenes for complex UI.

2. **Code Order Convention** - Variables and methods could be reordered to follow GDScript convention (signals, enums, constants, exports, vars, @onready, methods).

3. **Typed Arrays** - Could use `Array[Character]` syntax for better type safety.

### Recommendations for Future Work

1. **Scene Composition** - Build `party_status_panel.tscn`, `boss_hp_bar.tscn` as scenes instead of code-built UI
2. **AnimationPlayer** - Use for complex animation sequences instead of chained tweens
3. **Unique Node Names (`%`)** - Use for hierarchy-independent references

---

## Files Modified

| File | Changes |
|------|---------|
| ai_controller.gd | Removed `_update_phase()`, fixed `_select_highest_threat()` |
| status_effect_ids.gd | Fixed BLESS casing |
| damage_calculator.gd | Added null safety, added constants |
| battle_scene.gd | Added tween cleanup, removed prints, delegated to controllers |
| battle_manager.gd | Added actor lookup cache, added constants, fixed typo reference |
| action_factory.gd | Removed unused function, fixed typo reference |
| action_ids.gd | Removed unused constants, fixed typo |
| target_cursor.gd | Removed print statements |
| **actor_data.gd** | **NEW** - Actor data resource schema |
| **action_data.gd** | **NEW** - Action data resource schema |
| **data/actors/*.tres** | **NEW** - Actor data resources |
| **data/actions/*.tres** | **NEW** - Action data resources |
| **action_resolver.gd** | **NEW** - Action resolution extracted from battle_manager.gd |
| **turn_manager.gd** | **NEW** - Turn order and round flow extracted from battle_manager.gd |
| **status_processor.gd** | **NEW** - End-of-turn status processing extracted from battle_manager.gd |
| **battle_animation_controller.gd** | **NEW** - Animation logic extracted from battle_scene.gd |
| **battle_ui_manager.gd** | **NEW** - UI logic extracted from battle_scene.gd |
| **battle_renderer.gd** | **NEW** - Visual creation logic extracted from battle_scene.gd |

---

## Testing Notes

After applying these fixes, recommend testing:

1. **Phase transitions** - Verify boss phases change correctly at 60% and 30% HP
2. **Guard Stance targeting** - Verify boss attacks party members other than Ludwig when he's in Guard Stance
3. **BLESS status** - Verify Bless buff applies and provides damage bonus correctly
4. **Character KO** - Verify no visual artifacts when characters die
5. **Performance** - Verify no lag with optimized actor lookups

---

## Conclusion

All critical bugs (P0) and high-priority issues (P1) have been resolved. Medium-priority performance optimizations (P2) have been implemented. Most low-priority cleanup (P3) has been completed. The remaining items require significant architectural refactoring and are better addressed in a future sprint.
