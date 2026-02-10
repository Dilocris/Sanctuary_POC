<!--
DOC_ID: DOCS_MAINTENANCE
STATUS: ACTIVE - Documentation maintenance policy
LAST_UPDATED: 2026-02-09
SUPERSEDES: Informal doc maintenance rules scattered across files
SUPERSEDED_BY: None
-->

# Documentation Maintenance Rules

## Objectives
- Keep active docs short and decision-oriented.
- Avoid duplicate "source of truth" files.
- Preserve history without forcing repeated reads.

## Source-of-Truth Map
- Current status: `docs/STATUS.md`
- Backlog/execution: `docs/ROADMAP.md`
- Short running handoff log: `docs/AGENT_SWAP.md`
- Architecture direction: `docs/ARCHITECTURE.md`
- Program expansion phases: `docs/PROGRAM_PLAN.md`

## Active Doc Size Guidelines
- `STATUS.md`: <= 120 lines
- `AGENT_SWAP.md`: <= 300 lines (rolling summary only)
- `ROADMAP.md`: ticketized; avoid long narrative history inside
- New active docs: prefer <= 250 lines

## Archive Policy
Archive when any of the following is true:
1. Content is historical and no longer drives current decisions.
2. Another document already owns the same truth.
3. The file is primarily postmortem/reporting for a completed phase.

Archive locations:
- Session history: `docs/archive/logs/`
- Superseded docs: `docs/archive/legacy/`

## Session Logging Policy
- Append concise entries in `docs/AGENT_SWAP.md`.
- If log grows beyond target, copy full file to `docs/archive/logs/` and reset active log to concise summary.

## Doc Change Checklist
1. Update `LAST_UPDATED` in changed docs.
2. Update links in `docs/README.md` or `docs/REFERENCE_INDEX.md` if navigation changed.
3. Avoid creating a second "status" or "roadmap" document unless intentionally scoped.
4. Keep deprecated docs as stubs pointing to active replacements + archive path.
