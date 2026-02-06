# Phase 3 Refinements & Backlog

## Pending Refinements (Post-Agent Swap)

### 1. Catraca
- **Mage Armor Implementation**: Verify status application in UI. Current harness log showed "Bless" but not "Mage Armor" on Catraca. Need to debug `_handle_turn` logic ordering or `StatusEffectIds` string matching.
- **Fireball Targeting**: Currently selects specific hardcoded targets. Needs proper AoE selection logic (Start Phase 4 UI).

### 2. Ninos
- **Bardic Inspiration**: Logic currently consumes resource but doesn't apply the mechanical benefit (d8 to next attack). Needs a `Reaction` or `Modifier` system in `BattleManager`.
- **Healing Word**: Verify range/targeting constraints (currently infinite).

### 3. Ludwig
- **Precision Strike**: Mechanics are implemented (`multiplier: 1.2`), but the "Ignore Evasion" property does nothing because Evasion isn't implemented yet.
- **Guard Stance**: Needs mitigation logic (Damage Reduction) hooked into `apply_damage`. Currently just a tag.

### 4. General System
- **Status Effects**: verify `STAT_BUFF` vs `BUFF` usage across all new effects.
- **Mana/Resource UI**: The debugging `ResourceLabel` only shows Kairus. Needs to cycle or show all party members.

## Next Phase: Phase 4 (UI & Input)
- Implement `BattleMenu` (Attack, Skill, Item, Defend).
- Implement Target Selection Cursor.
- Wire Input events to `BattleManager` (replace `_run_demo_round` with real input).
