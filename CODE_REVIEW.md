# Sanctuary POC - Comprehensive Code Review

**Date:** 2026-02-03
**Branch:** code-review/comprehensive-review
**Godot Version:** 4.6

---

## Summary

This is a well-structured tactical RPG battle system POC with clear separation between game logic (`BattleManager`), presentation (`BattleScene`), and data definitions (Factories, IDs, Tags). The codebase demonstrates good use of Godot's signal system and follows many GDScript conventions. However, there are several areas for improvement across architecture, performance, and code quality.

---

## Critical Issues

### 1. Duplicate Phase Transition Logic (BUG RISK)
**Files:** [battle_manager.gd:727-742](scripts/battle_manager.gd#L727-L742), [ai_controller.gd:140-145](scripts/ai_controller.gd#L140-L145)

Phase transitions are calculated in two places independently, creating risk for state desync:

```gdscript
# battle_manager.gd:727
func _check_boss_phase_transition(target: Character) -> void:
    # ... calculates and sets phase

# ai_controller.gd:140
func _update_phase(boss: Boss) -> void:
    # ... also calculates and sets phase
```

**Impact:** Boss could enter wrong phase or phases could be skipped if HP changes rapidly.

**Fix:** Remove `_update_phase` from `AiController` - phase transitions should only happen through `BattleManager` which emits the `phase_changed` signal.

---

### 2. Incorrect "Highest Threat" Logic (BUG)
**File:** [ai_controller.gd:89-102](scripts/ai_controller.gd#L89-L102)

The function is supposed to ignore Ludwig in Guard Stance but instead **returns Ludwig** when he's in Guard Stance:

```gdscript
func _select_highest_threat(party: Array) -> String:
    var ludwig = _find_by_id(party, "ludwig")
    if ludwig != null and ludwig.has_status(StatusEffectIds.GUARD_STANCE):
        return "ludwig"  # BUG: Returns Ludwig instead of ignoring him
```

**Fix:** This condition should skip Ludwig and continue with threat calculation:
```gdscript
if ludwig != null and ludwig.has_status(StatusEffectIds.GUARD_STANCE):
    # Skip Ludwig in threat calc, fall through to attack calculation
    pass
```

---

### 3. Inconsistent Status ID Casing (BUG)
**File:** [status_effect_ids.gd:14](scripts/status_effect_ids.gd#L14)

```gdscript
const BLESS := "bless"  # lowercase - inconsistent with others
const ATK_UP := "ATK_UP"  # ALL_CAPS
```

This will cause `has_status(StatusEffectIds.BLESS)` to fail if checking against "BLESS".

**Fix:** Use consistent ALL_CAPS naming:
```gdscript
const BLESS := "BLESS"
```

---

### 4. Null Safety in Damage Calculation
**File:** [battle_manager.gd:143-166](scripts/battle_manager.gd#L143-L166)

`execute_basic_attack` can cause crashes with insufficient null checks:

```gdscript
func execute_basic_attack(attacker_id: String, target_id: String, multiplier: float = 1.0) -> Dictionary:
    var attacker = get_actor_by_id(attacker_id)
    var target = get_actor_by_id(target_id)
    # Early return for null - good
    if attacker == null or target == null:
        return ActionResult.new(false, "invalid_actor").to_dict()

    # But later...
    _try_riposte(attacker, target)  # OK
    # However in DamageCalculator, no null checks exist
```

**File:** [damage_calculator.gd:6](scripts/damage_calculator.gd#L6)

```gdscript
static func calculate_physical_damage(attacker: Node, defender: Node, multiplier: float) -> int:
    var atk = attacker.stats.get("atk", 0)  # Crashes if attacker is null
```

**Fix:** Add guard clause at start of `calculate_physical_damage`.

---

### 5. Memory Leak - Tweens Not Properly Killed
**File:** [battle_scene.gd:1330-1345](scripts/battle_scene.gd#L1330-L1345)

Looping tweens in `_start_idle_wiggle` are replaced without proper cleanup:

```gdscript
func _start_idle_wiggle(actor_id: String) -> void:
    if actor_idle_tweens.has(actor_id):
        var existing = actor_idle_tweens[actor_id]
        if existing:
            existing.kill()  # Good - kills old tween
    # ...
    tween.set_loops()  # Infinite loops - if actor dies, tween continues
    actor_idle_tweens[actor_id] = tween
```

**Issue:** When a character dies, their idle tween isn't stopped. Also, `_start_global_idle_all()` creates additional tweens without cleanup.

**Fix:** Add cleanup in KO state change handler and battle end.

---

## Improvements

### 6. Massive File Size - God Class Pattern
**Files:** [battle_scene.gd](scripts/battle_scene.gd) (1543 lines), [battle_manager.gd](scripts/battle_manager.gd) (998 lines)

Both files are too large and handle too many responsibilities.

**Recommendation:** Split into smaller, focused classes:
- `BattleScene` -> `BattleRenderer`, `BattleUIManager`, `BattleAnimationController`
- `BattleManager` -> `ActionResolver`, `TurnManager`, `StatusProcessor`

---

### 7. Excessive `get_actor_by_id()` Calls
**File:** [battle_manager.gd](scripts/battle_manager.gd)

`get_actor_by_id()` iterates through arrays every call. It's called 30+ times per action:

```gdscript
func get_actor_by_id(actor_id: String) -> Node:
    for actor in battle_state.party:  # O(n) each call
        if actor.id == actor_id:
            return actor
    for enemy in battle_state.enemies:
        if enemy.id == actor_id:
            return enemy
    return null
```

**Fix:** Use a Dictionary for O(1) lookups:
```gdscript
var _actor_lookup: Dictionary = {}

func _build_actor_lookup() -> void:
    _actor_lookup.clear()
    for actor in battle_state.party:
        _actor_lookup[actor.id] = actor
    for enemy in battle_state.enemies:
        _actor_lookup[enemy.id] = enemy

func get_actor_by_id(actor_id: String) -> Node:
    return _actor_lookup.get(actor_id, null)
```

---

### 8. Magic Numbers
**File:** [damage_calculator.gd](scripts/damage_calculator.gd), [battle_manager.gd](scripts/battle_manager.gd)

Multiple unexplained numeric values:

```gdscript
# damage_calculator.gd:16
defense *= 1.5  # What does 1.5 represent?

# battle_manager.gd:239
if randf() <= 0.5:  # 50% chance - for what?

# battle_manager.gd:508
if randf() <= 0.7:  # 70% chance - charm proc?

# battle_manager.gd:316
if randf() <= 0.40:  # 40% stun chance
```

**Fix:** Define constants with descriptive names:
```gdscript
const GUARD_STANCE_DEF_MULTIPLIER := 1.5
const STUNNING_STRIKE_PROC_CHANCE := 0.5
const DRAGONFIRE_CHARM_CHANCE := 0.7
const SHIELD_BASH_STUN_CHANCE := 0.4
```

---

### 9. Missing Static Typing
**File:** [battle_manager.gd](scripts/battle_manager.gd)

Mixed typing throughout - some variables typed, some not:

```gdscript
var battle_state := {  # Typed with inference
    "phase": 1,  # Dictionary values untyped
}

func get_actor_by_id(actor_id: String) -> Node:  # Return type could be Character|Boss|null
```

**Fix:** Use consistent static typing:
```gdscript
func get_actor_by_id(actor_id: String) -> Character:  # More specific
```

---

### 10. Code Order Not Following GDScript Convention
**File:** [battle_scene.gd](scripts/battle_scene.gd)

Current order is inconsistent. GDScript convention:
1. Signals
2. Enums
3. Constants
4. @export variables
5. Public variables
6. Private variables (with `_` prefix)
7. @onready variables
8. Methods

**Current state:** Variables mixed throughout, no `_` prefix on private vars.

---

### 11. Hardcoded Character Data
**File:** [battle_scene.gd:109-153](scripts/battle_scene.gd#L109-L153)

Character definitions hardcoded in `_ready()`:

```gdscript
var party: Array = [
    _make_character({
        "id": "kairus",
        "display_name": "Kairus",
        "stats": {"hp_max": 450, "mp_max": 60, "atk": 62, ...},
```

**Recommendation:** Move to Resource files (`.tres`) for data-driven design:
```gdscript
# character_data.tres
@export var id: String
@export var display_name: String
@export var base_stats: Dictionary
```

---

### 12. Unused Code
**File:** [action_factory.gd:166-174](scripts/action_factory.gd#L166-L174)

`ninos_inspire_defense` is defined but never used in `create_action`:

```gdscript
static func ninos_inspire_defense(actor_id: String, target_id: String) -> Dictionary:
    return {
        "action_id": ActionIds.NINOS_INSPIRE_DEFENSE,
        # ...
    }
```

**File:** [action_ids.gd:24](scripts/action_ids.gd#L24)

```gdscript
const CAT_MAGIC_MISSILE := "catraca_magic_missile"  # Never used
```

---

### 13. Empty Lines / Whitespace Issues
**File:** [battle_scene.gd:413-427](scripts/battle_scene.gd#L413-L427)

Excessive empty lines:

```gdscript
func _update_turn_order_visual() -> void:
    # ...
    turn_order_display.text = "Turn Order: " + " > ".join(display_order)




                    # 15+ blank lines here




func _print_turn_order(order: Array) -> void:
```

---

### 14. Missing `@onready` for Node References
**File:** [battle_scene.gd:3-42](scripts/battle_scene.gd#L3-L42)

Many UI nodes manually assigned in `_setup_game_ui()` instead of using `@onready`:

```gdscript
var boss_hp_bar: ProgressBar  # Not @onready
var phase_overlay: ColorRect  # Created programmatically

# vs

@onready var action_list_node = $Panel/ActionList  # battle_menu.gd - correct
```

**Note:** Since UI is built programmatically, this is somewhat intentional. Consider using scenes for complex UI.

---

### 15. Typo in Action ID
**File:** [action_ids.gd:35](scripts/action_ids.gd#L35)

```gdscript
const BOS_GREAXE_SLAM := "marcus_greataxe_slam"  # "GREAXE" typo in const name
```

The constant name has a typo (`GREAXE` vs `GREATAXE`), though the value is correct.

---

### 16. Print Statements Left in Code
**File:** [battle_scene.gd:441](scripts/battle_scene.gd#L441), [target_cursor.gd:133](scripts/ui/target_cursor.gd#L133)

```gdscript
print("Action enqueued: ", action)
print("Cursor targeting: ", target.name)
```

**Fix:** Remove or convert to `push_warning()` for debug builds only.

---

### 17. Signal Connection Style Inconsistency
**File:** [battle_scene.gd](scripts/battle_scene.gd)

Mixed signal connection styles:

```gdscript
# Method style (preferred in Godot 4)
battle_menu.action_selected.connect(_on_menu_action_selected)

# Lambda style
character.status_added.connect(func (status_id):
    _on_status_added(data.get("id", ""), status_id)
)
```

**Recommendation:** Use consistent style. Lambda is fine when passing extra context, but document the pattern.

---

## Good Practices

### Positive Highlights

1. **Factory Pattern** - `ActionFactory` and `StatusEffectFactory` centralize object creation cleanly.

2. **Signal-Based Architecture** - Good use of signals for loose coupling between `BattleManager` and `BattleScene`.

3. **Tag-Based System** - Flexible categorization for actions and status effects using arrays of tags.

4. **Separation of Concerns** - Logic (`BattleManager`) is separate from presentation (`BattleScene`).

5. **Guard Clauses** - Most functions check for null/invalid state early.

6. **Readable Action Resolution** - The large `match` statement in `_resolve_action` is well-organized.

7. **Defensive Programming** - `clamp()` used appropriately for HP/resources.

8. **Input Cooldowns** - Prevents input spam during animations.

---

## Godot-Specific Recommendations

### 1. Use Unique Node Names (`%`)
Instead of:
```gdscript
@onready var action_list_node = $Panel/ActionList
```
Consider:
```gdscript
@onready var action_list_node = %ActionList  # Works regardless of hierarchy
```

### 2. Scene Composition over Code-Built UI
`battle_scene.gd` builds most UI programmatically (1000+ lines). Consider:
- Create `party_status_panel.tscn`, `boss_hp_bar.tscn`, etc.
- Instantiate and configure in code

### 3. Use Typed Arrays (Godot 4.x)
```gdscript
var party: Array[Character] = []  # Instead of var party: Array = []
var status_effects: Array[StatusEffect] = []
```

### 4. AnimationPlayer for Complex Sequences
The phase overlay animation could be cleaner with AnimationPlayer:
```gdscript
# Instead of chained tweens
$PhaseOverlayAnimator.play("phase_transition")
```

---

## Status: Completed Fixes

| Priority | Issue | Status |
|----------|-------|--------|
| P0 | Duplicate phase transition logic | ✅ FIXED |
| P0 | Wrong threat selection logic | ✅ FIXED |
| P0 | Inconsistent BLESS casing | ✅ FIXED |
| P1 | Null safety in damage calc | ✅ FIXED |
| P1 | Memory leak - orphan tweens | ✅ FIXED |
| P2 | O(n) actor lookups | ✅ FIXED |
| P2 | Magic numbers | ✅ FIXED |
| P3 | Unused code cleanup | ✅ FIXED |
| P3 | Typo BOS_GREAXE_SLAM | ✅ FIXED |
| P3 | Print statements | ✅ FIXED |

---

## God Class Refactoring Progress

**battle_scene.gd:** 1555 → 948 lines (-39%)

| Phase | Component | Lines | Status |
|-------|-----------|-------|--------|
| 1 | BattleAnimationController | ~280 | ✅ Complete |
| 2 | BattleUIManager | ~430 | ✅ Complete |
| 3 | BattleRenderer | ~250 | ✅ Complete |

---

## Remaining Refactors (Reprioritized)

| Priority | Phase | Component | Impact | Notes |
|----------|-------|-----------|--------|-------|
| HIGH | 6 | ActionResolver | ~450 lines from battle_manager.gd | Biggest remaining god class reduction |
| HIGH | 7 | TurnManager + StatusProcessor | ~220 lines from battle_manager.gd | Completes battle_manager.gd split |
| MEDIUM | 4 | Character Data Resources | Data-driven design | Nice-to-have, enables designer editing |
| MEDIUM | 5 | Action Data Resources | Data-driven design | 34 .tres files, reduces ActionFactory |
| LOW | 8 | Boss AI Resources | Data-driven design | Enables phase/rotation config in .tres |

**Recommendation:** Prioritize Phase 6-7 to split battle_manager.gd before data-driven phases.

---

## Deferred Items (Low Priority)

- Code order convention (signals/enums/constants/vars ordering)
- Typed arrays `Array[Character]`
- Scene composition for UI (party_status_panel.tscn, etc.)
- AnimationPlayer for complex sequences
- Unique node names (`%NodeName`)

---

## Conclusion

All critical bugs (P0-P1) and performance issues (P2) are resolved. God class refactoring is 60% complete for battle_scene.gd. The codebase is significantly cleaner and more maintainable. Remaining work focuses on architectural improvements rather than bug fixes.
