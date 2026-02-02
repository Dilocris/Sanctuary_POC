# Tales of Sanctuary - Battle System Implementation Handoff

## Project Overview
We're building a single boss battle (Marcus Gelt) in SNES Final Fantasy 4 style using Godot 4.x.

## Key Documents
- **Main Reference:** `docs/battle_system_gdd.md` - Complete design specification
- **This File:** Implementation roadmap and current status

## Tech Stack
- **Engine:** Godot 4.x (GDScript)
- **IDE:** VS Code with Claude Code
- **Assets:** Generated with Gemini, refined manually

## Current Status
- [x] Godot project created
- [x] Project structure scaffolded
- [ ] Core battle system implemented
- [ ] Character abilities implemented
- [ ] Boss AI implemented
- [ ] UI/UX built
- [ ] Assets integrated
- [ ] Testing & polish

## Implementation Plan

### Phase 1: Project Structure
**Goal:** Set up folder structure and create base classes

**Tasks:**
1. Create folder structure:
```
   scenes/
   ├── battle/
   │   ├── battle_scene.tscn
   │   ├── character_node.tscn
   │   └── boss_node.tscn
   └── ui/
       ├── command_menu.tscn
       ├── hp_bar.tscn
       └── turn_order_panel.tscn
   
   scripts/
   ├── battle_manager.gd
   ├── character.gd
   ├── boss.gd
   ├── damage_calculator.gd
   ├── status_effect.gd
   └── ai_controller.gd
   
   assets/
   ├── sprites/
   │   ├── characters/
   │   └── boss/
   ├── vfx/
   ├── sfx/
   └── music/
   
   docs/
   └── battle_system_gdd.md
```

2. Create base Character class (scripts/character.gd) with:
   - Stats dictionary (HP, MP, ATK, DEF, MAG, SPD)
   - Resource tracking (Ki, Superiority Dice, etc.)
   - Status effects array
   - Action execution methods

3. Create BattleManager singleton (scripts/battle_manager.gd) with:
   - Turn order calculation
   - State management
   - Phase tracking

**Progress Notes (2026-02-02):**
- Folder structure matches Phase 1 list; placeholder .tscn files exist in `scenes/battle/` and `scenes/ui/`.
- Base `Character` class implemented with stats/resources/status helpers and action resource checks.
- `BattleManager` implemented with state skeleton, turn order calculation, and basic attack helper.
- Added `DamageCalculator` with physical damage formula + base crit (no elemental/status modifiers yet).
- Added `scripts/battle_scene.gd` and wired `scenes/battle/battle_scene.tscn` as a minimal harness to print turn order and execute a basic attack.
- Added on-screen debug Label in the battle scene harness to show turn order, attack result, and Marcus HP for quick visual feedback.
- Added scaffolding scripts for Phase 1 completeness: `scripts/status_effect.gd`, `scripts/boss.gd`, `scripts/ai_controller.gd`.
- Added end-of-turn status effect processing in `BattleManager` and a demo round runner in the battle scene to step through the full turn order.
- Updated the harness to use `Boss` for Marcus and apply a demo POISON status to validate DOT ticking.
- Added a demo REGEN status on Ninos to validate HOT ticking alongside POISON.
- Added a simple on-screen message log panel in the battle harness and wired it to `BattleManager` messages.
- Enemy turns in the harness now call `AiController` (stub) for a unified action path.
- `AiController` now returns a basic attack targeting the first living party member; the harness executes it.
- Added a turn order label wired to BattleManager signals and extended the demo to run two full rounds.
- Added an action queue scaffold in `BattleManager` (enqueue/process) for future ability execution.
- Harness now routes basic attacks through the action queue to validate the pipeline.
- `BattleManager` now logs queued/executed actions to the message log for visibility.
- Added `ActionIds` constants to centralize action identifiers and avoid magic strings.
- Added `ActionFactory` helper to standardize action dictionaries.
- Added action validation + action log in `BattleManager` and hooked queue/execution signals in the harness.
- Added an on-screen action log label to show the latest executed action result.
- Added `StatusEffectFactory` for consistent POISON/REGEN setup; harness now uses it.
- Added helper methods in `BattleManager` for applying status by id and querying living party/enemy lists.
- Added `ActionFactory.skip_turn`, AI now uses `ActionFactory`, and `BattleManager` validates actor/target state + stun/charm before execution.
- Added a queue size label to the harness plus action queue status updates.
- Added `ActionResult` wrapper for consistent action outcomes (ok/error/payload).
- Updated action processing + harness display to use ActionResult payloads.
- `execute_basic_attack` now returns an ActionResult payload with attacker/target/damage.
- Added Action tags/Status IDs constants and wired basic attack + status factory to use them.
- Added `battle_ended` signal in `BattleManager` and wired it in the harness.
- Added `StatusTags` + `ActionSchemaValidator` to reduce string drift and validate action shapes.
- Started Phase 3: added Kairus action IDs + ActionFactory entries (Flurry, Stunning Strike, Fire Imbue).
- `BattleManager` now resolves Kairus actions, consumes Ki, applies stun, and handles Fire Imbue toggle + Ki drain.
- Harness now alternates Kairus actions (Flurry/Fire Imbue) and displays Ki in a resource label.
- Harness now shows Fire Imbue ON/OFF and falls back to basic attack if Ki is insufficient.
- Action validation now checks resource costs.
- Increased message log limit for easier debugging (DOT/HOT visibility).
- Started Phase 3 Ludwig: added Guard Stance action + status toggle handling.

**Reference Sections in GDD:**
- Section 2: Core Battle System
- Section 8.1: State Management
- Section 8.2: Action Resolution Pipeline

### Phase 2: Core Combat Loop (CURRENT PHASE)
**Goal:** Basic attack system working with turn order

**Tasks:**
1. Implement turn order calculation (GDD Section 2.1) ✅
2. Implement physical damage formula (GDD Section 2.3) ✅
3. Create basic "Attack" action for all characters ✅ (BattleManager helper)
4. Test with 4 party members vs. 1 boss dummy
   - Pending: run Checkpoint A and confirm expected UI/console output

**Validation:** Can select Attack → damages boss → next turn advances

### Phase 3: Character Abilities
**Goal:** All 4 party members fully functional

**Implementation Order:**
1. Kairus (GDD Section 3.1)
   - Ki system
   - Fire Imbue toggle
   - Flurry of Blows, Stunning Strike, etc.
2. Ludwig (GDD Section 3.2)
   - Superiority Dice system
   - Guard stance toggle + Riposte passive
   - Maneuvers
3. Ninos (GDD Section 3.3)
   - Bardic Inspiration system
   - Magic spells (healing, buffs, control)
4. Catraca (GDD Section 3.4)
   - Sorcery Points
   - Metamagic system
   - Spell list

### Phase 4: Boss AI
**Goal:** Marcus Gelt fully functional with 3 phases

**Tasks:**
1. Implement Phase 1 behavior (GDD Section 4.3.1)
2. Implement Phase 2 behavior (GDD Section 4.3.2)
3. Implement Phase 3 behavior (GDD Section 4.3.3)
4. Phase transition system

### Phase 5: UI/UX
**Goal:** Visual interface complete

**Tasks:**
1. Command menus (GDD Section 5.2)
2. HP/MP/Resource bars (GDD Section 5.1)
3. Turn order panel
4. Status effect icons
5. Message log
6. Damage numbers

### Phase 6: Assets & Polish
**Goal:** Sprites, animations, VFX, SFX

**Tasks:**
1. Generate sprites with Gemini
2. Create animations
3. Add VFX (damage effects, spell effects)
4. Add SFX and music
5. Victory/defeat sequences

### Phase 7: Balance & Testing
**Goal:** Playable, balanced battle

**Tasks:**
1. Full battle playthrough
2. Tune damage numbers per GDD Section 9
3. Fix bugs
4. Polish

## Key Design Principles

### Action Tags System (CRITICAL)
Every ability must have tags for proper system processing. See GDD Section 2.4.

Example:
```gdscript
var flurry_of_blows = {
    "name": "Flurry of Blows",
    "tags": ["PHYSICAL", "RESOURCE", "SINGLE"],
    "resource_type": "Ki",
    "resource_cost": 2,
    "hit_count": 2,
    "damage_multiplier": 1.0
}
```

### Damage Formulas (See GDD Section 2.3)
Physical:
```gdscript
func calculate_physical_damage(attacker, defender, multiplier):
    var base = (attacker.stats.atk * multiplier) - (defender.stats.def * 0.5)
    var variance = base * randf_range(0.90, 1.10)
    # Check crit, apply elemental bonuses, etc.
    return max(1, floor(variance))
```

### Status Effects (See GDD Section 2.5)
All status effects have:
- ID (string)
- Duration (turns)
- Value (damage/heal per turn if applicable)
- Tags (for filtering and processing)

### Toggle Abilities (See GDD Section 3.2.3, 3.1.3)
- Guard Stance (Ludwig)
- Fire Imbue (Kairus)

These are status effects that remain active until toggled off.

## Common Pitfalls to Avoid

1. **Don't skip the GDD reference** - All mechanics are precisely defined
2. **Implement tags correctly** - They drive the entire action resolution system
3. **Test incrementally** - Don't build everything before testing
4. **Follow the phase order** - Don't jump ahead to UI before core combat works
5. **Keep turn order calculation separate** - It's a pure function, easy to test

## Questions to Ask When Stuck

1. "What does the GDD say about this mechanic?" (Check section references)
2. "What tags does this action need?"
3. "Is this a passive ability or active action?"
4. "Does this consume resources? What type?"
5. "Should this be in Character class or BattleManager?"

## Testing Checklist

After each phase, validate:
- [ ] Turn order advances correctly
- [ ] Damage formulas match GDD specifications
- [ ] Resources (Ki, MP, etc.) consume and track properly
- [ ] Status effects apply and expire correctly
- [ ] UI updates reflect game state accurately

## Testing Checkpoints

**Checkpoint A (Phase 2 smoke test)**
- Run `scenes/battle/battle_scene.tscn`
- Expect 2 full rounds, DOT/HOT ticks, and message log updates
- Confirm boss basic attack executes via `AiController`
- Expected UI: Turn order label updates per active actor, queue size updates, action log shows payloads
- Expected console: "Turn order:", "Action enqueued:", "Action executed:" lines across 2 rounds

## Next Steps for Claude Code

**Immediate Action:**
1. Test Phase 2 with 4 party members vs. 1 boss dummy
2. Expand the battle harness to advance turns across the full order ✅
3. Build `status_effect` application/ticking in `Character` and `BattleManager` ✅

**First Conversation Prompt:**
"I need to implement Phase 1 (Project Structure) for a SNES FF4-style turn-based battle system. The complete design document is in docs/battle_system_gdd.md. Please read it, then help me create the folder structure and base Character class with stats, resources, and status effect tracking."

## Reference Quick Links

**Character Specifications:**
- Kairus: GDD Section 3.1
- Ludwig: GDD Section 3.2
- Ninos: GDD Section 3.3
- Catraca: GDD Section 3.4

**Boss Specification:**
- Marcus Gelt: GDD Section 4

**Core Systems:**
- Turn System: GDD Section 2.1
- Damage Formulas: GDD Section 2.3
- Status Effects: GDD Section 2.5
- Action Tags: GDD Section 2.4

**Implementation Guides:**
- State Management: GDD Section 8.1
- Action Resolution: GDD Section 8.2
- AI Behavior: GDD Section 8.4

## File Naming Conventions

**Scripts:** snake_case (battle_manager.gd, character.gd)
**Scenes:** snake_case (battle_scene.tscn, command_menu.tscn)
**Assets:** descriptive names (kairus_idle.png, marcus_phase1_attack.png)

## Git Workflow (If Using Version Control)

Commit after each phase completion:
- "Phase 1: Project structure and base classes"
- "Phase 2: Core combat loop working"
- etc.

---

**Remember:** The GDD is law. When in doubt, check the document. All mechanics are defined there.
```

---

## **Step 3: Your First Prompt to Claude Code**

Open a new conversation in VS Code with Claude Code and start with:
```
I'm building a SNES Final Fantasy 4-style turn-based battle system in Godot 4.x. 

The complete design specification is in docs/battle_system_gdd.md and the implementation roadmap is in docs/PROJECT_HANDOFF.md.

Please read both documents carefully (they're in the project), then help me with Phase 1: Creating the project folder structure and implementing the base Character class.

Let's start by creating the folder structure, then we'll build scripts/character.gd with:
- Stats dictionary (HP, MP, ATK, DEF, MAG, SPD)
- Resource tracking for different character types (Ki, Superiority Dice, Bardic Inspiration, Sorcery Points)
- Status effects array
- Basic initialization

Reference GDD Sections 2.2 (Core Stats), 3.1-3.4 (Character Specifications), and 8.1 (State Management).

