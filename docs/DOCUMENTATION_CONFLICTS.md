# Documentation Conflicts Log

**Date:** 2026-02-04
**Purpose:** Track overlaps, inconsistencies, and redundancies in project documentation for future consolidation.

---

## Conflict 1: Handoff Document Overlap - RESOLVED

**Files:**
- [PROJECT_HANDOFF.md](PROJECT_HANDOFF.md)
- [AGENT_SWAP.md](AGENT_SWAP.md)

**Issue:** Both documents serve as handoff/context documents for agent swaps. There is significant overlap in content, but AGENT_SWAP.md has more recent entries and detailed session-by-session notes.

**Resolution (2026-02-04):**
- PROJECT_HANDOFF.md = Completed feature summary only (Section 3 removed)
- AGENT_SWAP.md = Primary handoff + session-by-session work log
- ROADMAP.md = New doc for prioritized pending work
- Pending items moved from PROJECT_HANDOFF to ROADMAP

---

## Conflict 2: Fix Documentation Overlap

**Files:**
- [CODE_REVIEW.md](../CODE_REVIEW.md)
- [FIXES_REPORT.md](../FIXES_REPORT.md)

**Issue:** Both documents track bug fixes and their status. CODE_REVIEW.md contains the original findings plus status tables, while FIXES_REPORT.md provides detailed fix documentation.

**Recommendation:**
- CODE_REVIEW.md = Findings only (freeze after review complete)
- FIXES_REPORT.md = Active fix tracking and implementation details
- Add cross-references between documents

**Information at Risk:** Status updates may diverge between documents.

---

## Conflict 3: Phase Documentation vs Handoff Documents

**Files (Archived):**
- [archive/PHASE_3_REFINEMENTS.md](archive/PHASE_3_REFINEMENTS.md)
- [archive/IMPLEMENTATION_PLAN_PHASE_4.md](archive/IMPLEMENTATION_PLAN_PHASE_4.md)

**Issue:** Archived phase docs contain some technical details that may not be fully captured in the handoff documents.

**Details:**
- PHASE_3_REFINEMENTS.md contained pending refinement items for Catraca, Ninos, Ludwig
- IMPLEMENTATION_PLAN_PHASE_4.md contained component structure details

**Recommendation:** Review archived docs before removing permanently. Verify all actionable items were transferred to handoff docs or completed.

**Verification Needed:**
- [ ] Bardic Inspiration mechanic - is it fully implemented or still placeholder?
- [ ] Fireball AoE targeting - does the current implementation match the plan?
- [ ] Status effect verification items from Phase 3 - were all resolved?

---

## Conflict 4: GDD vs Implementation - RESOLVED

**Files:**
- [battle_system_gdd.md](battle_system_gdd.md)
- Current codebase

**Issue:** The GDD is a reference document from initial design. Implementation may have diverged in some areas.

**Resolution (2026-02-04):**
- Added Section 12 "Implementation Notes" to GDD documenting:
  - 12.1 Implemented Divergences (Catraca Attack, Bless duration, etc.)
  - 12.2 Not Yet Implemented (Evasion, Counterspell, Rewards)
  - 12.3 Implementation Enhancements (features beyond GDD)
  - 12.4 Balance Adjustments

**Maintenance:** Update Section 12 when implementation diverges from design.

---

## Action Items

| Priority | Action | Status |
|----------|--------|--------|
| HIGH | Define clear purpose for PROJECT_HANDOFF vs AGENT_SWAP | DONE (2026-02-04) |
| MEDIUM | Add cross-references between CODE_REVIEW and FIXES_REPORT | DONE (headers added) |
| LOW | Review archived docs for missed items | DONE (moved to ROADMAP) |
| LOW | GDD reconciliation pass | DONE (Section 12 added) |

---

## Resolution Log

**2026-02-04:**
- Conflict 1 (Handoff overlap): Resolved by defining clear purposes and creating ROADMAP.md
- Conflict 4 (GDD divergence): Resolved by adding Section 12 Implementation Notes to GDD
- Archived phase docs reviewed: Pending items extracted to ROADMAP.md
