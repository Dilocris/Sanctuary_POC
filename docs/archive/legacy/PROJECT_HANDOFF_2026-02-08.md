<!--
DOC_ID: PROJECT_HANDOFF
STATUS: ACTIVE - High-level status snapshot
LAST_UPDATED: 2026-02-08
SUPERSEDES: archive/PHASE_3_REFINEMENTS.md, archive/IMPLEMENTATION_PLAN_PHASE_4.md
SUPERSEDED_BY: None

LLM USAGE INSTRUCTIONS:
- This document provides a HIGH-LEVEL feature summary (what's done).
- For PENDING WORK, see ROADMAP.md.
- For session-by-session notes, see AGENT_SWAP.md.
- READ Section 1 for completed features.
- SKIP Section 2 (file manifest) unless investigating specific files.

QUICK REFERENCE:
- Completed features: Section 1
- File manifest: Section 2
- How to run: Section 3
- Pending work: See ROADMAP.md
-->

# Project Handoff - Agent Swap Complete

## Date: 2026-02-08
## Status: Combat Prototype Active - Production Backlog Formalized

### Roadmap Update (Production Plan)
- `docs/ROADMAP.md` has been refactored into a ticketized production backlog with:
  - milestone sequencing
  - file/system scope per ticket
  - measurable acceptance criteria
  - locked design decisions and quality gates

### Procedure Update (Parser Safety)
- After **any** `.gd` edit, run:
  - `powershell -ExecutionPolicy Bypass -File scripts/dev/check_gdscript_sanity.ps1`
- This check blocks handoff if it finds merge markers or split GDScript keywords (example: `i  f`) that cause class parse failures.
- If Godot CLI is available locally, also run a headless parse/open to confirm script load before commit.

### Procedure Update (Scene Transition Safety)
- Before any scene reload/change, explicitly shut down async controllers that use timers/tweens (`BattleAnimationController.shutdown()`).
- In timer/tween callbacks that can outlive a frame, guard with `is_instance_valid(...)` and a scene-root validity check before `add_child`, `create_tween`, or `get_tree`.
- This prevents runtime crashes like: `Cannot call method 'add_child' on a previously freed instance.`

### 1. Completed Features
- **Ludwig Von Tannhauser**:
  - `Guard Stance` (Toggle, Status Logic)
  - Maneuvers: `Lunging Attack`, `Precision Strike`, `Shield Bash`, `Rally`.
  - Superiority Dice resource management.
- **Ninos the Bard**:
  - Actions: `Vicious Mockery` (Deals dmg + ATK_DOWN), `Healing Word`, `Bless`.
  - Inspiration: `Inspire Attack` logic placeholder.
- **Catraca the Sorcerer**:
  - Actions: `Fire Bolt`, `Fireball` (AoE logic), `Mage Armor`.
  - Metamagic: Placeholder structure ready.
- **Battle Harness (`battle_scene.tscn`)**:
  - Full party loop (Kairus, Ludwig, Ninos, Catraca) vs Marcus Gelt.
  - Active Status Effects display UI.
  - Interactive loop demonstrating all new abilities.
- **Phase 4 UI Scaffolding**:
  - `BattleMenu` + `TargetCursor` scenes/scripts added.
  - `battle_scene.gd` now drives player turns via menu/target selection.
  - Battle log panel (top-left) shows recent messages + effect results with turn separators.
  - Limit gauge bar displayed per character in party panel.
- **Feedback/Polish Pass**:
  - Boss HP bar now uses a thicker pill bar with color thresholds.
  - Active turn highlighting in party panel + name-under-sprite labels.
  - Added idle sway, action whip, and hit shake to sprites.
  - Damage numbers are larger, orange, and stagger for multi-hit.
  - Non-active idle is now stepped (2 keyframes, low amplitude) with per-actor phase offsets.
  - Party panel HP uses pill bars with bold current HP and smaller max HP.
  - Limit Break uses a progress bar (grey until 100%, blue at full) with aligned % text.
  - Limit Breaks are now wired for all four heroes with a cinematic overlay text per activation.
  - Limit Gauge now accrues on damage dealt and damage taken (DOT included, lower gain for DOT).
  - Enemy telegraph shows a 2s intent callout using player-facing action names.
  - Menu cursor now uses a small diamond marker; description panel shifted to avoid overlap.
  - Catraca’s Attack now uses Fire Bolt; Fire Bolt removed from Magic submenu.
  - ATK_DOWN now scales damage using the status value (default 25%).

### 2. File Manifest
- `scripts/action_ids.gd`: Added IDs for all Phase 3 actions.
- `scripts/action_factory.gd`: Added factory methods for all new actions.
- `scripts/status_effect_ids.gd`: Added `ATK_DOWN`, `MAGE_ARMOR`, `GUARD_STANCE`.
- `scripts/status_effect_factory.gd`: Implemented logic for new statuses (using `STAT_BUFF` tag).
- `scripts/status_tags.gd`: Verified `STAT_BUFF` vs `BUFF` (Canonical is `STAT_BUFF`).
- `scripts/battle_manager.gd`: Implemented execution logic for all new ActionIDs.
- `scripts/battle_scene.gd`: Updated `_handle_turn` with specific logic for each character class.
- `scenes/ui/battle_menu.tscn` + `scripts/ui/battle_menu.gd`: Menu UI + input handling.
- `scenes/ui/target_cursor.tscn` + `scripts/ui/target_cursor.gd`: Target selection cursor.
- `docs/IMPLEMENTATION_PLAN_PHASE_4.md`: Menu/targeting plan.

### 3. How to Run
Open `scenes/battle/battle_scene.tscn` and run. Watch the output log and the new UI panels.

---

### See Also
- **[ROADMAP.md](ROADMAP.md)** - Prioritized backlog of pending work
- **[AGENT_SWAP.md](AGENT_SWAP.md)** - Session-by-session work log and handoff notes
