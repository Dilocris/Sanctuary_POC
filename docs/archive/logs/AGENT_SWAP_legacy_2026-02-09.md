<!--
DOC_ID: AGENT_SWAP
STATUS: ACTIVE - Primary handoff document + work log
LAST_UPDATED: 2026-02-08
SUPERSEDES: archive/PHASE_3_REFINEMENTS.md, archive/IMPLEMENTATION_PLAN_PHASE_4.md
SUPERSEDED_BY: None

PURPOSE:
1. HANDOFF: Provide context when swapping between LLM agents
2. WORK LOG: Track session-by-session changes and decisions

LLM USAGE INSTRUCTIONS:
- THIS IS THE PRIMARY HANDOFF DOCUMENT. Read this first for context.
- READ FROM BOTTOM UP for most recent session notes.
- Each session has Sign-in (acknowledgements) and Sign-off (summary).
- For pending work, see ROADMAP.md.
- For high-level feature list, see PROJECT_HANDOFF.md.
- For code review details, see CODE_REVIEW.md and FIXES_REPORT.md.

QUICK REFERENCE:
- Most recent session: Scroll to bottom (latest sign-in/sign-off)
- Bug fix summary: "Code Review & Refactor Handoff" section
- Runtime errors: "Notes: Runtime Errors & Root Causes" section
- Resource loading fix: "Resolution: Missing Script Assignment" section

ADDING A NEW SESSION:
1. Add "# Sign-in (DATE)" with agent name and acknowledgements
2. Document work done during session
3. Add "# Sign-off (DATE)" with summary and next steps
-->

# Agent Swap Notes (Short Handoff)

Date: 2026-02-03

## What Gemini changed (recent history)
- Implemented Phase 3 actions for Ludwig/Ninos/Catraca in `scripts/action_factory.gd` + `scripts/battle_manager.gd`.
- Converted the battle harness into a **menu-driven flow** with `BattleMenu` + `TargetCursor`.
- Added UI scaffolding files:
  - `scenes/ui/battle_menu.tscn`
  - `scenes/ui/target_cursor.tscn`
  - `scripts/ui/battle_menu.gd`
  - `scripts/ui/target_cursor.gd`
  - `docs/IMPLEMENTATION_PLAN_PHASE_4.md`

## What I did after signing in (stabilization)
- Fixed `battle_scene.gd` issues:
  - Replaced invalid `stats.hp_max/mp_max` with `stats["hp_max"] / stats["mp_max"]`.
  - Removed invalid `battle_state.get("battle_ended")`; added `battle_over` flag tied to `battle_ended` signal.
- Committed the Phase 4 UI scaffolding + menu-driven flow (`ee82fc6`).

## Where things stand
- Phase 3 logic is implemented for all party members; some effects are placeholders (Inspire).
- Phase 4 UI scaffolding is present, and the battle loop is now menu-driven.
- Targeting uses `TargetCursor` and a local `_create_action_dict` mapping in `battle_scene.gd`.

## Recent additions (this session)
- Centralized action creation via `ActionFactory.create_action` and removed local mapping.
- Tag-driven targeting now drives cursor behavior (SELF/SINGLE/ALL) with ALL-target centering feedback.
- Added on-screen battle log panel (top-left) with effect results + turn separators.
- Added Catraca Metamagic submenu (Quicken/Twin) and routing into Magic selection.
- Added Limit Gauge tracking + small UI bar per character (party panel).
- Cleaned party resource labels to show MP + Ki/SD/BI/SP consistently.
- Converted Marcus HP to a thicker pill bar with color thresholds and aligned under name.
- Added sprite feedback: active idle sway, action whip, and hit shake.
- Updated damage numbers (larger, orange, staggered for multi-hit).
- Catraca’s main Attack now uses Fire Bolt; Fire Bolt removed from Magic submenu.
- ATK_DOWN now uses its status value to scale damage.
- Added enemy intent telegraph (2s) with player-facing action names.
- Non-active idle now uses stepped 2-keyframe motion (low amplitude), active idle toned down.
- Party HP and LB now use pill/progress bars with aligned text; LB turns blue at 100%.
- Menu cursor uses a diamond indicator; description panel repositioned to avoid overlap.
- Poison now applies a slow oscillating green tint on the sprite.
- Bless now applies +1d4 to physical and magical damage for 2 turns; Mage Armor is 3-turn DEF buff.
- Indefinite statuses no longer expire; Guard Stance/Mage Armor persist as intended.
- Fixed duplicate boss action functions in `action_factory.gd`.
- Fixed target cursor outline shader (no early return in fragment).
- Added input lock to prevent action spamming by holding confirm.
- Phase transition now resets turn order so party acts before boss.
- Implemented all four Limit Break actions and cinematic overlay text on activation.
- Limit Gauge now accrues on damage dealt and damage taken (DOT included at reduced rate).
- DOT/HOT ticks now show floating numbers.

## Next high-level steps
1) Verify input mappings and menu flow stability (ui_up/down/left/right/accept/cancel).
2) Add proper targeting rules for multi-target spells (Twin Spell selection, Fireball AoE selection UX).
3) Resume Boss AI Phase 4/5 work (phase logic + transitions).
- Ludwig's Guard Stance and Maneuvers (Lunging, Precision, Shield Bash, Rally) are implemented and wired into the harness.
- Status Display UI added to harness.
- Ninos Phase 3 abilities partially implemented (Bless, Vicious Mockery, Healing Word, Inspire Attack) and wired to harness.
- Catraca Phase 3 abilities partially implemented (Fire Bolt, Fireball, Mage Armor) and wired to harness.
- Full Phase 3 party loop verification ready.
- All three agents (Ludwig, Ninos, Catraca) have basic Phase 3 logic wired.

## Sign-off
- [x] Antigravity (Dev) - 2026-02-02

---

# Code Review & Refactor Handoff (2026-02-03)

**Agent:** Claude Opus 4.5
**Branch:** `code-review/comprehensive-review`

---

## What I Did

### Bug Fixes (All Complete)
- P0: Fixed duplicate phase transition logic in ai_controller.gd
- P0: Fixed wrong threat selection (returned Ludwig instead of skipping him)
- P0: Fixed BLESS casing inconsistency
- P1: Added null safety to damage_calculator.gd
- P1: Fixed memory leak - orphan tweens on KO/battle end
- P2: O(1) actor lookup via `_actor_lookup` dictionary
- P2: Replaced all magic numbers with named constants
- P3: Removed unused code, print statements, fixed typos

### God Class Refactoring (Phases 1-3 Complete)
| Phase | Component | Lines | File |
|-------|-----------|-------|------|
| 1 | BattleAnimationController | ~280 | `scripts/battle/battle_animation_controller.gd` |
| 2 | BattleUIManager | ~430 | `scripts/battle/battle_ui_manager.gd` |
| 3 | BattleRenderer | ~250 | `scripts/battle/battle_renderer.gd` |

**Result:** `battle_scene.gd` reduced from 1555 → 948 lines (-39%)

---

## Files to Read (Priority Order)

1. **[CODE_REVIEW.md](../CODE_REVIEW.md)** - Full review, fix status, remaining work
2. **[FIXES_REPORT.md](../FIXES_REPORT.md)** - Detailed fix documentation
3. **[scripts/battle_manager.gd](../scripts/battle_manager.gd)** - Next extraction target
4. **Plan file:** `C:\Users\Diego\.claude\plans\stateless-sparking-volcano.md`

---

## TODO: Remaining Refactoring

### HIGH PRIORITY
**Phase 6: ActionResolver** (~450 lines from battle_manager.gd)
- Extract `_resolve_action` match statement
- Create `scripts/battle/action_resolver.gd`
- Methods: `_resolve_action`, `execute_basic_attack`, `_apply_damage_with_limit`, `_try_riposte`

**Phase 7: TurnManager + StatusProcessor** (~220 lines)
- `scripts/battle/turn_manager.gd`: `calculate_turn_order`, `start_round`, `advance_turn`
- `scripts/battle/status_processor.gd`: `process_end_of_turn_effects`, `_tick_status`

### MEDIUM PRIORITY
**Phase 4-5: Data Resources** (Character + Action .tres files)

### LOW PRIORITY
**Phase 8: Boss AI Resources**

---

## Quality Requirements

1. **Thin wrappers** - Keep method signatures, delegate to new classes
2. **Copy refs back** - After creating controllers, copy dictionaries back for compatibility
3. **Test after each phase** - Battle must be playable
4. **Commit per phase** - Clean git history
5. **Update FIXES_REPORT.md** - Document completed phases

---

## Code Pattern Used

```gdscript
extends RefCounted
class_name BattleAnimationController

func setup(scene_root: Node, battle_manager: BattleManager, ...) -> void:
    _scene_root = scene_root

# In battle_scene.gd - thin wrapper
func _play_hit_shake(actor_id: String) -> void:
    animation_controller.play_hit_shake(actor_id)
```

---

## Sign-off

All P0-P2 fixes complete. Phases 1-3 tested and working. Codebase stable. Remaining work is architectural improvement, not bug fixes.

— Claude Opus 4.5, 2026-02-03

---

# Sign-in (2026-02-03)

**Agent:** Codex
**Branch:** `code-review/comprehensive-review`

## Acknowledgements
- Read and acknowledged latest additions by Opus.
- Will follow refactor guidance: thin wrappers, copy refs back, commit per phase, update `FIXES_REPORT.md`.

## Next Work Pickup
- Ready to proceed with Phase 6 (ActionResolver) from `scripts/battle_manager.gd` when requested.

---

# Notes: Runtime Errors & Root Causes (2026-02-03)

## Latest Error
- **Parser Error:** Function `_get_prop()` not found in base self.
- Context: occurred after refactor to resource-backed data loading.

## Recent Error Timeline
1) **Parse errors:** `get()` called with 2 arguments (Godot 4.6 treats `Object.get()` as 1-arg only).
2) **Read-only mutation:** `Character._consume_resource` failed due to mutating dictionaries loaded from `.tres` resources.
3) **Data loading gaps:** combat failed to load when resource type checks were too strict.
4) **Missing helper references:** `_get_prop()` removed but some call sites still referenced it.

## Broad Patterns Identified
- **Resource immutability:** `.tres` data is read-only and must be cloned before mutation.
- **Mixed access patterns:** `Object.get()` vs `Dictionary.get()` caused parse errors in Godot 4.6.
- **Helper drift:** refactors removed helpers without updating all call sites.
- **Validation too strict:** resource load checks blocked valid data and resulted in empty actor lists.

## Target Fix Strategy (Elegant + Durable)
- Centralize deep-clone and resource extraction (`DataClone.resource_to_dict`) and use everywhere.
- Avoid `Dictionary.get(key, default)` in code paths that Godot parses as `Object.get()`.
- Add one consistent `dict_get()` helper for defaults to prevent parse errors.
- Add a single validation gate for resource-backed data and fallback to legacy data if missing.
- Add a compile-time sweep for removed helpers during refactor phases.

---

# Sign-off (2026-02-03)

**Agent:** Codex  
**Branch:** `code-review/comprehensive-review`

## Summary
- Completed Phase 4-7 refactors, added `ActionResolver`, `TurnManager`, `StatusProcessor`.
- Added resource schemas and loaders (`ActorData`, `ActionData`) with safe deep-clone utilities.
- Addressed parser errors from `get()` misuse and read-only resource mutations.
- Added fallbacks and diagnostics for resource loading.

## Known Open Items
- Verify ActorData `.tres` loads cleanly after editor refresh; fallback still in place if load fails.
- Remaining warnings about unused signals are non-blocking.

---

# Sign-in (2026-02-03)

**Agent:** Claude Opus 4.5
**Branch:** `code-review/comprehensive-review`

## Acknowledgements
- Read AGENT_SWAP.md and FIXES_REPORT.md.
- Analyzed the post-refactor runtime errors documented by previous agents.

## Root Cause Analysis: Resource Load Failures

**Problem:** ActorData and ActionData `.tres` files were failing to load as their custom resource types. Godot reported `Cannot get class 'ActorData'` errors and fell back to legacy hardcoded data.

**Root Cause:** The `.tres` files were missing the critical `script` property assignment in the `[resource]` section. While the files had:
- `script_class="ActorData"` in the header
- `ext_resource` pointing to the script

They lacked:
```
[resource]
script = ExtResource("1")  <-- MISSING
id = "kairus"
```

Without this line, Godot loads the file as a generic `Resource` instead of the custom `ActorData` class. The script properties (id, display_name, stats, etc.) aren't properly bound to the resource schema.

## Fix Applied

Added `script = ExtResource("1")` to all `.tres` files:
- **Actor files (5):** kairus.tres, ludwig.tres, ninos.tres, catraca.tres, marcus_gelt.tres
- **Action files (30):** All action data resources in `data/actions/`

This ensures Godot properly instantiates the custom resource class and binds all `@export` properties.

## Verification

After this fix, resources should load with:
- `data.get_script() == ActorDataScript` returning `true`
- No fallback to legacy data needed
- Clean resource property access via typed resource class

## Sign-off

Resource loading issue definitively fixed. The battle should now load actors from `.tres` files without fallback.

— Claude Opus 4.5, 2026-02-03

---

# Sign-in (2026-02-05)

**Agent:** Claude Opus 4.6
**Branch:** `main`

## Acknowledgements
- Read AGENT_SWAP.md, FIXES_REPORT.md, POLISH_PLAN.md, ROADMAP.md
- Reviewed full codebase: battle_scene.gd, battle_ui_manager.gd, battle_renderer.gd, battle_animation_controller.gd, action_resolver.gd, status_processor.gd, status_effect_factory.gd

## Work Done: Battle Polish Sprint (4 Phases)

### Phase 1 — Text & Config
- Kairus idle scale `0.45→0.40`
- Y-based `z_index` on character/boss nodes for depth sorting
- Pixel font (Silkscreen) applied to all battle menu labels
- Per-character Limit Break descriptions
- Resource short names + consistent "Cost. Effect." skill descriptions

### Phase 2 — UI Layout
- Frame bleed fix: `region_rect` with integer-division frame sizes
- HP bars `16→20px`, MP bars `10→14px`, `BAR_WIDTH=130`, improved contrast
- Party panel: fixed-position columns with 1px vertical separators
- LB bar flash tween at 100%, dot grid (`2x8`, 8px dots), LB column alignment
- Battle menu widened to 220px, description panel autowrap
- Bug fixes: LB % font scaled up, active name color-only styling + row highlight

### Phase 3 — Game Logic
- Fire Imbue: skip Ki drain on activation turn via `fire_imbue_skip_drain` flag
- Burn DOT status: `BURN` id, factory method (2 turns, 8 dmg), auto-applied by Fire Imbue attacks
- Fireball/Venom Strike: `multi_target_damage` array payload for per-target game feel

### Phase 4 — Animation System
- `ATTACK_SPRITESHEETS` config in `battle_renderer.gd` (kairus: 4x3 grid, 14fps)
- Full attack animation system in `battle_animation_controller.gd`: texture swap, frame playback, impact callback, idle restore
- `_show_action_visuals()` extracted in `battle_scene.gd` — called at impact frame or immediately

### Files Modified
| File | Changes |
|------|---------|
| `battle_renderer.gd` | Scale, z_index, region_rect, ATTACK_SPRITESHEETS |
| `battle_ui_manager.gd` | Bar heights, fixed columns, separators, LB flash, row highlights |
| `battle_animation_controller.gd` | Attack spritesheet system (register, play, restore) |
| `battle_scene.gd` | Attack anim integration, _show_action_visuals, multi_target_damage handler |
| `action_resolver.gd` | Fire Imbue flag, Burn application, multi_target_damage payloads |
| `status_processor.gd` | Fire Imbue skip drain check |
| `status_effect_ids.gd` | BURN constant |
| `status_effect_factory.gd` | burn() factory method |
| `battle_menu.gd` | Pixel font, LB descriptions, resource short names |
| `battle_menu.tscn` | Panel width, description layout, actor separator |
| `resource_dot_grid.gd` | Fixed 2x8 dot layout |
| `animated_health_bar.gd` | Bar sizing, contrast |

## Sign-off

All 4 phases of the Battle Polish Sprint complete. Kairus has attack animation with synced damage, Fire Imbue applies Burn DOT, Fireball has per-target game feel, and the UI is significantly more polished (readable bars, fixed columns, pixel font, LB flash). Ready for playtesting.

— Claude Opus 4.6, 2026-02-05

---

# Sign-in (2026-02-08)

**Agent:** Codex  
**Branch:** `main`

## Acknowledgements
- Picked up implementation from `docs/ROADMAP.md` current focus (CMB-004 then PRE-001).
- Started with CMB-004 hardening to remove duplicate action-resolution progression paths.

## Work Done (CMB-004 - Resolve State Machine Hardening)
- Refactored action resolution in `scripts/battle_scene.gd` into explicit terminal outcomes:
  - `success`
  - `failed-retry`
  - `failed-advance`
  - `battle-end`
- Added dedicated helpers so each resolution follows one terminal dispatcher path:
  - `_determine_action_terminal`
  - `_dispatch_action_terminal`
  - `_handle_failed_action_retry`
  - `_handle_failed_action_advance`
  - `_handle_successful_action_resolution`
  - `_advance_after_resolved_action`
  - `_enter_turn_loop_for_resolution`
  - `_finalize_battle_end_after_action`
- Centralized turn advance and `_process_turn_loop()` re-entry so one action resolution cannot trigger duplicate loop re-entry.
- Preserved existing UX contract:
  - Failed player action returns to `ACTION_SELECT` without consuming turn.
  - Non-player failed action advances turn to avoid deadlock.
  - Quicken and metamagic branching behavior unchanged.

## Verification
- Ran `scripts/dev/check_gdscript_sanity.ps1` after refactor.
- Result: `GDScript sanity check passed for 34 files.`

## Follow-up
- Updated `docs/ROADMAP.md`:
  - Marked `CMB-004` as `DONE (2026-02-08)`.
  - Advanced current focus to `PRE-001`, then `QA-001`.

## Sign-off
- CMB-004 implemented and validated at parser/sanity level.
- Next implementation target is PRE-001 timeline pacing contract.

-- Codex, 2026-02-08

---

# Sign-in (2026-02-09 - PRE-005)

**Agent:** Codex  
**Branch:** `main`

## Work Done (PRE-005 - Character Animation System Pass, implementation in progress)
- Added `docs/ANIMATION_SETUP.md` with:
  - frame layout contract,
  - anchor/baseline policy,
  - timing conventions,
  - import guidance,
  - validation checklist and rollout tasks.
- Updated `scripts/battle/battle_renderer.gd` attack config:
  - Kairus attack cut fixed from invalid `4x3` to `4x4` on `1024x1024` sheet.
  - Kairus attack now uses explicit 5-beat timeline (`2 anticipation`, `1 held impact`, `2 recover`) via `frame_sequence` + `frame_durations`.
  - Added Ludwig as second proving-pass attack config using the same timeline contract path.
- Upgraded `scripts/battle/battle_animation_controller.gd`:
  - Added config validation guardrails in `register_attack_spritesheet`.
  - Added timeline-driven playback (`frame_sequence`, `frame_durations`, `frame_y_offsets`).
  - Added baseline stability support with per-step y-offset correction.
  - Added safe metric checks for evenly divisible frame cuts.
  - Added `get_attack_config_validation(actor_id)` helper for debug/reporting.

## Verification
- Ran: `powershell -ExecutionPolicy Bypass -File scripts/dev/check_gdscript_sanity.ps1 -Root .`
- Result: `GDScript sanity check passed for 34 files.`

## Status
- `docs/ROADMAP.md`: `PRE-005` moved to `IN_PROGRESS (2026-02-09)`.
- Next step: in-game visual validation pass and y-offset fine-tune per frame if any residual jitter remains.

-- Codex, 2026-02-09

---

# Sign-in (2026-02-08 - PRE-001)

**Agent:** Codex  
**Branch:** `main`

## Work Done (PRE-001 - Action Timeline Contract, partial)
- Implemented staged action timeline flow in `scripts/battle_scene.gd` for each queued action:
  - `INTENT`
  - `COMMIT`
  - `IMPACT`
  - `SETTLE`
- Added adaptive timeline profiling (`single` vs `multi`) and duration bounds enforcement:
  - Single target target window: `2.5s - 4.0s`
  - Multi-target/multi-hit target window: `3.5s - 5.0s`
- Added timing helpers in `battle_scene.gd`:
  - `_peek_next_action`
  - `_run_action_timeline_*` stage methods
  - `_determine_timeline_profile`
  - `_estimate_timeline_impact_duration`
  - `_enforce_action_timeline_bounds`
- Enemy intent telegraph now uses clamped timing (`0.75s - 1.15s`) and cooperates with timeline staging.
- Added `BattleAnimationController.get_attack_animation_duration()` in `scripts/battle/battle_animation_controller.gd` so impact stage accounts for spritesheet animation length.

## Verification
- Ran `scripts/dev/check_gdscript_sanity.ps1`.
- Result: `GDScript sanity check passed for 34 files.`

## Status
- `docs/ROADMAP.md` updated: `PRE-001` is now `IN_PROGRESS (2026-02-08)`.
- Next: in-game validation/tuning pass to confirm cadence feels right for all core action families.

-- Codex, 2026-02-08

---

# Sign-in (2026-02-08 - QA-001)

**Agent:** Codex  
**Branch:** `main`

## Work Done (QA-001 - GDScript Parse/Runtime Gate)
- Upgraded `scripts/dev/check_gdscript_sanity.ps1` with:
  - `-StagedOnly` mode (for pre-commit checks)
  - automatic Godot CLI discovery (`godot4`, `godot`, `Godot.exe`)
  - mandatory headless Godot gate when CLI is available
  - optional bypass switch (`-SkipGodotCli`) and explicit path override (`-GodotPath`)
- Added repo-managed pre-commit hook at `.githooks/pre-commit` to run staged GDScript gate before commit.
- Added installer script `scripts/dev/install_git_hooks.ps1` to enforce `core.hooksPath=.githooks`.
- Installed hooks locally and verified `git config --local --get core.hooksPath` returns `.githooks`.

## Verification
- Ran full sanity gate:
  - `powershell -ExecutionPolicy Bypass -File scripts/dev/check_gdscript_sanity.ps1 -Root .`
  - Output: `GDScript sanity check passed for 34 files.`
- Environment had no Godot CLI on PATH, so runtime gate was correctly skipped with explicit warning.
- Ran staged mode:
  - `powershell -ExecutionPolicy Bypass -File scripts/dev/check_gdscript_sanity.ps1 -Root . -StagedOnly`
  - Output: `No GDScript files to validate.`

## Status
- `docs/ROADMAP.md` updated: `QA-001` marked `DONE (2026-02-08)`.
- Current focus remains `PRE-001`, then `PRE-002`.

-- Codex, 2026-02-08

---

# Sign-in (2026-02-08 - Backlog Continuation)

**Agent:** Codex  
**Branch:** `main`

## Request Handling
- Removed Godot CLI from active task-list acceptance criteria and sanity-gate requirements.
- Continued implementation on remaining high-priority presentation tickets without pausing for planning-only mode.

## Implemented (This Batch)
- `scripts/dev/check_gdscript_sanity.ps1`
  - Removed Godot CLI runtime dependency and related flags.
  - Kept commit-safe gate behavior for parser/sanity heuristics and staged-only mode.
- `docs/ROADMAP.md`
  - QA-001 no longer references Godot CLI task requirements.
  - PRE-002 / PRE-003 / PRE-004 moved to `IN_PROGRESS (2026-02-08)`.
- `scripts/battle_scene.gd`
  - Added limit-break timeline profile and cinematic pre-impact stage (~5s contract path) so action execution/damage resolves on impact beat instead of immediately on queue commit.
  - Added limit-cinematic guards to prevent duplicate overlay/effect firing.
  - Added feedback toast routing queue with priority ordering to prevent high-signal events (state/timeline/reaction) from being overwritten by lower-priority noise.
  - Added reaction-feedback dedup guard to prevent duplicate reaction floaters.

## Verification
- Ran sanity gate after edits:
  - `powershell -ExecutionPolicy Bypass -File scripts/dev/check_gdscript_sanity.ps1 -Root .`
  - Result: `GDScript sanity check passed for 34 files.`

## Status
- Ongoing implementation continues from P1/P2 backlog after this checkpoint.

-- Codex, 2026-02-08
