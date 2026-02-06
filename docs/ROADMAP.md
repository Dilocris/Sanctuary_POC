<!--
DOC_ID: ROADMAP
STATUS: ACTIVE - Prioritized backlog
LAST_UPDATED: 2026-02-04
SUPERSEDES: Pending items from PROJECT_HANDOFF.md Section 3
SUPERSEDED_BY: None

LLM USAGE INSTRUCTIONS:
- This is the BACKLOG for future work. Check here before starting new features.
- Items are prioritized: HIGH > MEDIUM > LOW.
- Mark items DONE when completed and add completion date.
- For current session context, see AGENT_SWAP.md.

QUICK REFERENCE:
- Gameplay gaps: Section "Gameplay Mechanics"
- UX improvements: Section "UI/UX Polish"
- Architecture: Section "Technical Debt"
-->

# Sanctuary POC - Roadmap

**Last Updated:** 2026-02-04

---

## Priority Legend
- **HIGH** - Blocks core gameplay or causes bugs
- **MEDIUM** - Important for polish/completeness
- **LOW** - Nice to have, can defer

---

## Gameplay Mechanics

### HIGH Priority

| Item | Description | Source | Status |
|------|-------------|--------|--------|
| Bardic Inspiration Effect | Currently consumes resource but doesn't apply +1d8 to next attack. Needs `Reaction` or `Modifier` system in damage calculation. | PHASE_3_REFINEMENTS | PENDING |
| Evasion System | Not implemented. Precision Strike's "Ignore Evasion" and Patient Defense passive have no effect. | PHASE_3_REFINEMENTS | PENDING |

### MEDIUM Priority

| Item | Description | Source | Status |
|------|-------------|--------|--------|
| Twin Spell Targeting | Twin metamagic needs proper 2-target selection UI. Currently wired but UX incomplete. | AGENT_SWAP | PENDING |
| Quicken Spell Guardrails | Second-action after Quicken needs refinement to prevent invalid states. | AGENT_SWAP | PENDING |
| Fireball AoE Selection | Fireball hits all enemies automatically. Consider UX for selective AoE if needed. | PHASE_3_REFINEMENTS | PENDING |

### LOW Priority

| Item | Description | Source | Status |
|------|-------------|--------|--------|
| Healing Word Range | Currently infinite range. Verify if range constraint needed per GDD. | PHASE_3_REFINEMENTS | VERIFY |
| Boss AI Phase 8 | Boss AI as data resources (.tres) for phase/rotation config. | CODE_REVIEW | DEFERRED |

---

## UI/UX Polish

### HIGH Priority

| Item | Description | Source | Status |
|------|-------------|--------|--------|
| Yellow Health Bar | Delayed "recent damage" bar that drains to current HP. | POLISH_PLAN | PENDING |
| HP Number Scroll | Odometer-style digit rolling for HP changes. | POLISH_PLAN | PENDING |

### MEDIUM Priority

| Item | Description | Source | Status |
|------|-------------|--------|--------|
| Cursor Tint | Higher contrast cursor for readability. | POLISH_PLAN | PENDING |
| Hit Stop | 2-6 frame pause on impactful hits. | POLISH_PLAN | PENDING |
| Camera Shake | Light shake on heavy hits/crits. | POLISH_PLAN | PENDING |
| Low HP Warning | Vignette or heartbeat at critical HP threshold. | POLISH_PLAN | PENDING |

### LOW Priority

| Item | Description | Source | Status |
|------|-------------|--------|--------|
| Floater Readability | Re-evaluate damage number stacking during bursts. | POLISH_PLAN | PENDING |
| FX Intensity Options | Player settings for shake/flash/hit stop intensity. | POLISH_PLAN | PENDING |
| Audio Feedback | HP tick sounds, impact layers, block/guard SFX. | POLISH_PLAN | PENDING |

---

## Technical Debt

### MEDIUM Priority

| Item | Description | Source | Status |
|------|-------------|--------|--------|
| Typed Arrays | Use `Array[Character]` syntax for type safety. | CODE_REVIEW | DEFERRED |
| Scene Composition | Build UI as scenes (party_status_panel.tscn) instead of code. | CODE_REVIEW | DEFERRED |
| AnimationPlayer | Use for complex animation sequences instead of chained tweens. | CODE_REVIEW | DEFERRED |
| Code Order Convention | Reorder to GDScript convention (signals, enums, constants, vars). | CODE_REVIEW | DEFERRED |

### LOW Priority

| Item | Description | Source | Status |
|------|-------------|--------|--------|
| Unique Node Names | Use `%NodeName` for hierarchy-independent references. | CODE_REVIEW | DEFERRED |

---

## Completed Items

| Item | Description | Completed | Notes |
|------|-------------|-----------|-------|
| BattleMenu | Menu-driven action selection | 2026-02-03 | Phase 4 |
| Target Cursor | Visual targeting with tag-based filtering | 2026-02-03 | Phase 4 |
| Guard Stance | DEF * 1.5, damage * 0.5, Riposte | 2026-02-03 | Phase 3 |
| Mage Armor | 3-turn DEF buff | 2026-02-03 | Phase 3 |
| Bless | +1d4 to attacks for 2 turns | 2026-02-03 | Phase 3 |
| Resource UI | All party resources visible | 2026-02-03 | Phase 4 |
| Limit Breaks | All 4 heroes wired with cinematic overlay | 2026-02-03 | Phase 4 |
| Boss AI Phases 1-3 | Full rotation + phase transitions | 2026-02-03 | Phase 4 |
| God Class Refactor | Phases 1-7 complete (-39% lines) | 2026-02-03 | Review |
| Data Resources | ActorData + ActionData .tres files | 2026-02-03 | Review |

---

## Open Questions

_Decisions needed before implementation._

1. **Evasion System Scope** - Full evasion system or just for specific abilities?
2. **Inspiration Timing** - Should Bardic Inspiration apply to next attack only, or persist until used?
3. **AoE Selection** - Should Fireball allow selective targeting or always hit all enemies?
4. **FX Accessibility** - What's the minimum FX set for accessibility mode?

---

## How to Update This Document

1. Add new items to appropriate section with source reference
2. Move completed items to "Completed Items" section with date
3. Update "Last Updated" date at top
4. For decisions, add to "Open Questions" until resolved
