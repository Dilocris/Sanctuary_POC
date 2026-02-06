# Phase 4 Implementation Plan: UI & Input

## Overview
Implement the player interaction layer, allowing users to select actions via a menu system rather than the auto-running demo loop.

## Components

### 1. BattleMenu (`scenes/ui/battle_menu.tscn`)
**Structure:**
- **Root**: Control node.
- **ActionList**: VBoxContainer for main actions (Attack, Skills, Defend, Items).
- **SubMenu**: Panel for specific skills/items when selected.
- **DescriptionPanel**: Text label for tooltip/description of selected action.

**Logic (`scripts/ui/battle_menu.gd`):**
- State machine for menu navigation (MAIN -> SUBMENU -> TARGETING).
- `setup(actor)`: Populates menu based on active character's class/actions.
- Signals: `action_selected(action_id)`, `cancel`.

### 2. TargetSelection (`scripts/ui/target_cursor.gd`)
- Visual indicator (Sprite or Shader) over the potential target.
- Inputs: UI_LEFT/RIGHT to cycle targets.
- Logic: Filter valid targets based on action tags (SINGLE, ALL_ENEMIES, ALL_ALLIES, SELF).

### 3. Input Integration (`scripts/battle_manager.gd` & `battle_scene.gd`)
- **Pause State**: BattleManager needs a state `WAITING_FOR_INPUT`.
- **Harness Update**: Modify `BattleScene` to instantiate `BattleMenu` and show it when it's a player's turn.
- **Connection**:
  1. `BattleManager` signals `player_turn_started(actor)`.
  2. `BattleScene` shows `BattleMenu`.
  3. Player selects action -> `BattleMenu` emits signal.
  4. If target needed -> `TargetCursor` activates.
  5. Target selected -> `BattleManager.enqueue_action(action)`.

## Execution Steps
1. **Scaffold UI**: Create `BattleMenu` scene and script.
2. **Implement Menu Logic**: key handling for up/down, population of `ActionFactory` data.
3. **Implement Targeting**: Basic visual cursor.
4. **Wire to Manager**: Stop the auto-loop and listen for signals.
