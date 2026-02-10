# Sanctuary POC - Documentation Index

**Last Updated:** 2026-02-05

---

## LLM Agent Quick Start

**Starting a new session?** Read these in order:
1. **[AGENT_SWAP.md](AGENT_SWAP.md)** - Current project status and recent changes (READ BOTTOM SECTION FIRST)
2. **[battle_system_gdd.md](battle_system_gdd.md)** - Only if you need design reference (SKIP sections 7, 10, 11)

**Investigating a bug?** Read:
1. **[../CODE_REVIEW.md](../CODE_REVIEW.md)** - Original findings
2. **[../FIXES_REPORT.md](../FIXES_REPORT.md)** - Applied fixes and patterns

**Planning polish/UX work?**
1. **[POLISH_PLAN.md](POLISH_PLAN.md)** - Pending polish features

---

## Document Quick Reference

| Document | Purpose | When to Read |
|----------|---------|--------------|
| [AGENT_SWAP.md](AGENT_SWAP.md) | Handoff + work log | **ALWAYS** - Start here |
| [ROADMAP.md](ROADMAP.md) | Prioritized backlog | Before starting new work |
| [PROJECT_HANDOFF.md](PROJECT_HANDOFF.md) | Completed feature summary | Quick feature overview |
| [battle_system_gdd.md](battle_system_gdd.md) | Master design + impl notes | Design questions, formulas |
| [POLISH_PLAN.md](POLISH_PLAN.md) | UX/feedback planning | Polish implementation |
| [../CODE_REVIEW.md](../CODE_REVIEW.md) | Code review findings | Bug investigation |
| [../FIXES_REPORT.md](../FIXES_REPORT.md) | Applied fix details | Bug investigation |
| [DOCUMENTATION_CONFLICTS.md](DOCUMENTATION_CONFLICTS.md) | Known doc conflicts | Reconciliation work |

---

## Active Documents

### Primary Handoff
- **[AGENT_SWAP.md](AGENT_SWAP.md)** - Session-by-session agent handoff + work log. Most recent context at bottom.

### Backlog
- **[ROADMAP.md](ROADMAP.md)** - Prioritized pending work. Check before starting new features.

### Feature Status
- **[PROJECT_HANDOFF.md](PROJECT_HANDOFF.md)** - High-level completed feature summary.

### Design Reference
- **[battle_system_gdd.md](battle_system_gdd.md)** - Original battle system design document with implementation notes (Section 12). ~2400 lines. Use section index in header.

### Code Quality
- **[../CODE_REVIEW.md](../CODE_REVIEW.md)** - Comprehensive code review. All P0-P2 issues resolved.
- **[../FIXES_REPORT.md](../FIXES_REPORT.md)** - Detailed fix documentation and refactoring progress.

### Planning
- **[POLISH_PLAN.md](POLISH_PLAN.md)** - UX/feedback polish ideas (planning only, no code).

### Meta
- **[DOCUMENTATION_CONFLICTS.md](DOCUMENTATION_CONFLICTS.md)** - Tracks overlaps and inconsistencies between documents.

---

## Archived Documents

Located in `docs/archive/`. These are **outdated** and superseded by current handoff documents.

| Document | Reason Archived | Superseded By |
|----------|-----------------|---------------|
| GODOT_NOTES.md | Empty/abandoned | N/A |
| PHASE_3_REFINEMENTS.md | Phase 3 complete | AGENT_SWAP.md |
| IMPLEMENTATION_PLAN_PHASE_4.md | Phase 4 complete | AGENT_SWAP.md |

**Warning:** Do not read archived documents for current context. They may contain outdated information.

---

## Context Loading Guidelines

### Minimal Context (Quick Tasks)
Read only: **AGENT_SWAP.md** (bottom section)

### Standard Context (Feature Work)
Read: **AGENT_SWAP.md** + relevant GDD section

### Full Context (Major Changes)
Read: **AGENT_SWAP.md** + **CODE_REVIEW.md** + **battle_system_gdd.md** (selectively)

### Bug Investigation
Read: **CODE_REVIEW.md** + **FIXES_REPORT.md** + relevant code files

---

## Document Ownership

| Document | Primary Maintainer | Update Frequency |
|----------|-------------------|------------------|
| AGENT_SWAP.md | Each agent session | Per session |
| PROJECT_HANDOFF.md | Major milestones | Infrequent |
| battle_system_gdd.md | Design changes only | Rare |
| CODE_REVIEW.md | Review complete | Frozen |
| FIXES_REPORT.md | Bug fixes | As fixes applied |
| POLISH_PLAN.md | Polish planning | As needed |

---

## How to Update This Index

When adding new documentation:
1. Add entry to "Active Documents" or "Archived Documents" section
2. Update "Document Quick Reference" table
3. Add LLM header block to new document (see existing docs for template)
4. Update "Last Updated" date at top
