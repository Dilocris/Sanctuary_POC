<!--
DOC_ID: STATUS
STATUS: ACTIVE - Current project snapshot
LAST_UPDATED: 2026-02-09
SUPERSEDES: docs/PROJECT_HANDOFF.md (as primary current snapshot)
SUPERSEDED_BY: None
-->

# Project Status

## Current Stage
Combat prototype is playable end-to-end in a single battle harness (`scenes/battle/battle_scene.tscn`).

## What is working now
- Turn-based combat loop with 4 heroes vs boss.
- Data-backed actors/actions (`data/actors`, `data/actions`).
- Core battle UI/feedback systems and animation pipeline.
- Difficulty selection and reward summary panel.

## Current limitations (important)
- Project is still battle-first, not adventure-first.
- Most action behavior is still hardcoded by `action_id` in resolver logic.
- Encounter and menu logic are still character/boss specific in key places.
- No overworld/city/NPC/dialogue/quest/save architecture yet.

## Immediate priorities
1. Reach combat foundation lock (stable, reusable encounter framework).
2. Shift to RPG architecture foundations (state, scenes, narrative, save, content pipeline).
3. Build first vertical slice (city -> quest/dialogue -> exploration -> encounters -> resolution).

## Navigation
- Backlog: `docs/ROADMAP.md`
- Rolling implementation log: `docs/AGENT_SWAP.md`
- Scale-up architecture direction: `docs/ARCHITECTURE.md`
- Program phases: `docs/PROGRAM_PLAN.md`
