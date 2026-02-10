<!--
DOC_ID: PROGRAM_PLAN
STATUS: ACTIVE - High-level expansion phases from prototype to simple RPG
LAST_UPDATED: 2026-02-09
SUPERSEDES: Implicit expansion notes in battle_system_gdd.md Section 10
SUPERSEDED_BY: None
-->

# Program Plan: Prototype -> Simple RPG Adventure

## Phase 0: Combat Foundation Lock
Output:
- Combat loop stable and reusable beyond a single handcrafted boss flow.
- At least 2-3 encounter patterns working with consistent targeting/reactions/timelines.

Exit criteria:
- No major flow blockers in combat smoke checks.
- New encounter can be authored mostly with data and minimal code edits.

## Phase 1: Core RPG Infrastructure
Output:
- `GameState`, `SaveSystem`, `SceneRouter` foundations.
- Player progression state survives scene transitions and reloads.

Exit criteria:
- Save/load restores party, resources, flags, and current location reliably.

## Phase 2: Adventure Loop Scaffolding
Output:
- Overworld/city map scene with movement + interactables.
- NPC interaction shell (nameplate, prompt, interaction callback).

Exit criteria:
- Player can move, interact, trigger dialogue, and return control cleanly.

## Phase 3: Narrative and Quest Systems
Output:
- Dialogue graph with branching choices and conditional nodes.
- Quest state model (not started/in progress/completed).

Exit criteria:
- One quest runs from accept -> update -> completion with state persistence.

## Phase 4: Combat Integration in Adventure
Output:
- Encounter triggers from exploration into combat and back.
- Rewards and quest updates integrated into post-combat transitions.

Exit criteria:
- World->combat->world loop completes without manual resets or data loss.

## Phase 5: Vertical Slice 1
Output:
- One campaign chunk end-to-end:
  - city block
  - 3-5 NPCs
  - branching dialogue quest
  - exploration path
  - regular encounters
  - boss encounter
  - narrative resolution

Exit criteria:
- Slice is fully playable and replayable with save/load.

## Parallel Rule (all phases)
- Allocate most effort to current phase objective.
- Reserve limited bandwidth for combat regressions and high-impact fun improvements.
