<!--
DOC_ID: ARCHITECTURE
STATUS: ACTIVE - Current and target system architecture
LAST_UPDATED: 2026-02-09
SUPERSEDES: Ad-hoc architecture notes across AGENT_SWAP/FIXES_REPORT
SUPERSEDED_BY: None
-->

# Architecture: Current vs Target

## Current Architecture (Prototype)

### Runtime center
- `scripts/battle_scene.gd`: scene orchestration, flow, input routing, timeline, visuals dispatch.
- `scripts/battle_manager.gd`: combat state, queueing, turn progression, core battle services.

### Extracted subsystems (good progress)
- `scripts/battle/action_resolver.gd`
- `scripts/battle/action_pipeline.gd`
- `scripts/battle/turn_manager.gd`
- `scripts/battle/status_processor.gd`
- `scripts/battle/reaction_resolver.gd`
- `scripts/battle/battle_ui_manager.gd`
- `scripts/battle/battle_animation_controller.gd`
- `scripts/battle/battle_renderer.gd`

### Data layer
- Actors and actions are resource-backed (`scripts/resources/*.gd`, `data/**/*.tres`).
- IDs/tags/status constants exist and are reusable.

### Main scaling pain points
- Resolver and menu behavior are still heavily `action_id` and actor-id specific.
- Encounter logic is mostly single-boss-script oriented.
- Non-combat game loop systems are missing.

## Target Architecture (Simple RPG scale)

### Global systems (autoloads)
- `GameState`: party, inventory, quests, flags, progression.
- `SceneRouter`: deterministic scene transitions and return points.
- `SaveSystem`: slot-based serialize/deserialize of `GameState`.
- `ContentDB`: data registry/cache for encounters, maps, dialogues, items.

### Gameplay domains
- `CombatDomain`: reusable encounter runner, encounter definitions, enemy behavior profiles.
- `AdventureDomain`: exploration maps, interactables, NPC controllers, quest triggers.
- `NarrativeDomain`: dialogue graphs, branching choices, flag gates, cutscene steps.

### Content-first structures
- Encounter definitions: enemy sets, AI profiles, rewards, scripted events.
- Dialogue graph resources: node/choice/condition/effect.
- Quest resources: objectives, state transitions, rewards.
- Map metadata: encounter zones, NPC spawn sets, interaction points.

## Migration Strategy
1. Stabilize and generalize combat flow for multiple encounter definitions.
2. Introduce global `GameState` + `SaveSystem`.
3. Add exploration scene loop and NPC interaction.
4. Integrate dialogue graph + quest state.
5. Connect encounter triggers from world scenes to combat runner.
6. Ship one complete vertical slice before widening scope.

## Guardrails
- Keep battle fun improvements, but avoid deep combat rewrites during architecture pivot.
- Prefer data-driven additions over new hardcoded character/boss branches.
- Keep active docs concise and move historical details to archive.
