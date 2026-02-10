<!--
DOC_ID: AGENT_SWAP
STATUS: ACTIVE - Rolling handoff and short work log
LAST_UPDATED: 2026-02-09
SUPERSEDES: Historical long-form AGENT_SWAP log
SUPERSEDED_BY: None
-->

# Agent Swap (Rolling)

This file is intentionally short.

## Default read order
1. `docs/STATUS.md`
2. `docs/ROADMAP.md`
3. This file (`docs/AGENT_SWAP.md`)

## Legacy history
Full historical session log is archived at:
- `docs/archive/logs/AGENT_SWAP_legacy_2026-02-09.md`

Do not read the legacy log unless timeline reconstruction is required.

## Current snapshot
- Combat prototype is playable end-to-end in one battle harness.
- Priority has shifted from battle-only polish to RPG scalability preparation.
- Documentation structure was consolidated to reduce context waste and duplication.

## Recent work log (newest first)

### 2026-02-09 - Documentation architecture reset
- Archived legacy copies of superseded docs into `docs/archive/logs` and `docs/archive/legacy`.
- Created canonical doc hub and active doc set:
  - `docs/README.md`
  - `docs/STATUS.md`
  - `docs/ARCHITECTURE.md`
  - `docs/PROGRAM_PLAN.md`
  - `docs/DOCS_MAINTENANCE.md`
  - `docs/REFERENCE_INDEX.md`
- Converted overlap-prone docs to compatibility stubs:
  - `docs/INDEX.md`
  - `docs/PROJECT_HANDOFF.md`
  - `docs/DOCUMENTATION_CONFLICTS.md`

### 2026-02-09 - PRE-005 (in progress)
- Added animation authoring contract in `docs/ANIMATION_SETUP.md`.
- Added spritesheet validation guardrails and timeline-driven frame playback.
- Next gameplay-side step: visual validation/fine tuning in-engine.

## How to append
- Add concise entries only (what changed, why, next step).
- Keep this file under ~300 lines.
- Archive full history when it grows beyond that limit.
