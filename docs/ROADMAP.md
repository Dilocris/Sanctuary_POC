<!--
DOC_ID: ROADMAP
STATUS: ACTIVE - Production backlog and delivery plan
LAST_UPDATED: 2026-02-08
SUPERSEDES: Prior ad-hoc roadmap table
SUPERSEDED_BY: None

LLM USAGE INSTRUCTIONS:
- This document is the source of truth for pending combat/gameplay/UI work.
- Execute tickets in sprint order unless dependencies force reorder.
- Each ticket must satisfy all acceptance criteria before moving to DONE.
- Log implementation notes in docs/AGENT_SWAP.md after each ticket completion.
-->

# Sanctuary POC - Production Roadmap

**Last Updated:** 2026-02-08

## Product Direction
Target feel: readable, high-impact turn flow inspired by the pace and clarity of **Chrono Trigger** and **Sea of Stars**.

Design pillars:
1. Fast command loop with strong action payoff.
2. Clear tactical consequences every turn.
3. High readability under load (effects, statuses, reactions, logs).
4. Boss encounters that pressure decisions through mechanics, not only HP inflation.

## Locked Decisions
1. Failed player actions should not consume turn.
2. Riposte may trigger even if Ludwig was not hit.
3. KO allies are targetable by healing effects; KO enemies are never targetable.
4. Genie's Wrath applies to damaging spells only and should be described that way.

## Sprint Sequence
1. **Sprint A (Stability + Cadence Foundation):** CMB-004, PRE-001, QA-001
2. **Sprint B (Presentation + UX Clarity):** PRE-002, PRE-003, UX-001, UX-003
3. **Sprint C (Combat Depth + Encounter Script):** DSG-001..004, ENC-001..003
4. **Sprint D (Balance + Release Readiness):** BAL-001..003, QA-002

---

## Ticket Backlog

### Milestone M0 - Core Loop Integrity (P0)

#### CMB-001 - Failed Action Turn Handling
- Priority: P0
- Status: DONE (2026-02-08)
- Systems/Files:
  - `scripts/battle_scene.gd`
- Acceptance Criteria:
  1. If `process_next_action()` returns `ok=false` on player turn, battle returns to `ACTION_SELECT` for same actor.
  2. No end-of-turn status processing runs on failed player action.
  3. No accidental turn advance occurs for failed player action.

#### CMB-002 - Target Validity Policy (KO Rules)
- Priority: P0
- Status: DONE (2026-02-08)
- Systems/Files:
  - `scripts/battle_scene.gd`
  - `scripts/ui/target_cursor.gd`
- Acceptance Criteria:
  1. Healing actions can select KO allies.
  2. Enemy target pools always exclude KO enemies.
  3. All-target confirms obey same KO filtering rules.

#### CMB-003 - Genie's Wrath Scope Enforcement
- Priority: P0
- Status: DONE (2026-02-08)
- Systems/Files:
  - `scripts/battle/action_resolver.gd`
  - `scripts/battle_scene.gd`
  - `scripts/ui/battle_menu.gd`
  - `scripts/battle/battle_ui_manager.gd`
- Acceptance Criteria:
  1. MP waiver applies only to damaging spells (`CAT_FIRE_BOLT`, `CAT_FIREBALL`).
  2. Non-damaging spells do not consume Wrath charges.
  3. UI descriptions explicitly say "damaging spells".

#### CMB-004 - Resolve State Machine Hardening
- Priority: P0
- Status: TODO
- Systems/Files:
  - `scripts/battle_scene.gd`
  - `scripts/battle_manager.gd`
- Acceptance Criteria:
  1. Exactly one terminal branch per action resolution (`success`, `failed-retry`, `failed-advance`, `battle-end`).
  2. No duplicate `_process_turn_loop()` entry from one action.
  3. State transitions logged once per boundary.

---

### Milestone M1 - Moment-to-Moment Presentation (P1)

#### PRE-001 - Action Timeline Contract
- Priority: P1
- Status: TODO
- Systems/Files:
  - `scripts/battle_scene.gd`
  - `scripts/battle/battle_animation_controller.gd`
  - `scripts/battle/game_feel_controller.gd`
- Acceptance Criteria:
  1. Normal single-target actions resolve in 2.5s-4.0s.
  2. Multi-hit actions resolve in 3.5s-5.0s.
  3. Timeline stages standardized: intent -> commit -> impact -> settle.

#### PRE-002 - Limit Break Cinematic Pipeline (~5s)
- Priority: P1
- Status: TODO
- Systems/Files:
  - `scripts/battle_scene.gd`
  - `scripts/battle/battle_animation_controller.gd`
  - `scripts/battle/action_resolver.gd`
- Acceptance Criteria:
  1. Limit break runs a 4.5s-6.0s sequence with camera/overlay/impact beats.
  2. Damage applies on impact beat, not instantly on queue.
  3. Input locked during cinematic and restored cleanly afterward.

#### PRE-003 - Feedback Priority Router
- Priority: P1
- Status: TODO
- Systems/Files:
  - `scripts/battle_scene.gd`
  - `scripts/battle/battle_ui_manager.gd`
- Acceptance Criteria:
  1. Per action, one primary feedback channel (damage/reaction/limit), secondary channels delayed/staggered.
  2. Combat log toasts do not overwrite higher-priority events.
  3. State transition text remains visible during noisy turns.

#### PRE-004 - Reaction Impact Pass
- Priority: P1
- Status: TODO
- Systems/Files:
  - `scripts/battle_manager.gd`
  - `scripts/battle_scene.gd`
  - `scripts/battle/reaction_resolver.gd`
- Acceptance Criteria:
  1. Every reaction has consistent motion + damage feedback + log callout.
  2. Riposte uses same readability standards as regular actions.
  3. No duplicate reaction damage/floaters.

---

### Milestone M2 - Readability and UX (P1)

#### UX-001 - Floater System v2
- Priority: P1
- Status: IN_PROGRESS
- Systems/Files:
  - `scripts/battle/battle_animation_controller.gd`
  - `scripts/battle_scene.gd`
- Acceptance Criteria:
  1. No overlapping unreadable stacks in 4-hit burst scenario.
  2. Miss/heal/status/damage all use distinct color/typography rules.
  3. Floaters always render above scene/UI elements.

#### UX-002 - Lower HUD Numeric Alignment and Scannability
- Priority: P1
- Status: IN_PROGRESS
- Systems/Files:
  - `scripts/ui/animated_health_bar.gd`
  - `scripts/battle/battle_ui_manager.gd`
- Acceptance Criteria:
  1. HP and MP values centered to bars at 100%/50%/low values.
  2. LB bar fill and text are both readable in motion.
  3. MP low state remains visually distinct from HP danger language.

#### UX-003 - Tooltip Coverage and Reliability
- Priority: P1
- Status: IN_PROGRESS
- Systems/Files:
  - `scripts/battle/battle_ui_manager.gd`
  - `scripts/ui/battle_menu.gd`
- Acceptance Criteria:
  1. Status icons always show name + effect + duration.
  2. Resource/LB widgets consistently show hover tooltips.
  3. Hover is not blocked by floating feedback or overlay controls.

#### UX-004 - Menu Navigation and Scroll Robustness
- Priority: P1
- Status: TODO
- Systems/Files:
  - `scripts/ui/battle_menu.gd`
  - `scenes/ui/battle_menu.tscn`
- Acceptance Criteria:
  1. Long skill lists never hide selectable options.
  2. Disabled reasons are shown for every blocked action.
  3. Guard stance always has a non-resource spend pass-turn option.

---

### Milestone M3 - Combat Design Depth (P1)

#### DSG-001 - Ludwig Tank Loop Finalization
- Priority: P1
- Status: TODO
- Systems/Files:
  - `scripts/battle/action_resolver.gd`
  - `scripts/battle_manager.gd`
  - `scripts/ui/battle_menu.gd`
- Acceptance Criteria:
  1. Guard Stance meaningfully shifts threat and mitigation behavior.
  2. Taunt + Rally have clear synergy without overshadowing other choices.
  3. Lunging vs Precision are differentiated by reliability and payoff in real encounters.

#### DSG-002 - Ninos Support Tradeoff Pass
- Priority: P1
- Status: TODO
- Systems/Files:
  - `scripts/battle/action_resolver.gd`
  - `scripts/status_effect_factory.gd`
  - `scripts/ui/battle_menu.gd`
- Acceptance Criteria:
  1. Healing Word and Cleanse each have distinct "best-use" windows.
  2. Bless and Inspire scale percentages feel impactful but not mandatory.
  3. Ability descriptions exactly match mechanics and numbers.

#### DSG-003 - Catraca Spell/Metamagic Loop
- Priority: P1
- Status: TODO
- Systems/Files:
  - `scripts/battle/action_resolver.gd`
  - `scripts/battle_manager.gd`
  - `scripts/ui/battle_menu.gd`
- Acceptance Criteria:
  1. Magic-first command flow remains intuitive.
  2. Metamagic states are obvious and cannot produce hidden invalid turns.
  3. Wrath and metamagic interactions are documented and deterministic.

#### DSG-004 - Status Economy Tuning
- Priority: P1
- Status: TODO
- Systems/Files:
  - `scripts/status_effect_factory.gd`
  - `scripts/battle/status_processor.gd`
  - `scripts/damage_calculator.gd`
- Acceptance Criteria:
  1. Poison/Burn influence turn decisions in Hard mode.
  2. Cleanse timing matters; not always optimal on cooldown.
  3. Status durations and values are visible and believable in combat logs/UX.

---

### Milestone M4 - Encounter Scripting (P1/P2)

#### ENC-001 - Boss Intent Script Templates
- Priority: P1
- Status: TODO
- Systems/Files:
  - `scripts/ai_controller.gd`
  - `scripts/battle_manager.gd`
  - actor/action data resources
- Acceptance Criteria:
  1. Boss turns communicate tactical objective (burst, setup, punish, sustain).
  2. At least 2 counterplay windows per phase.
  3. Intent text maps to actual behavior and timings.

#### ENC-002 - Collector's Grasp Consequence Chain
- Priority: P1
- Status: TODO
- Systems/Files:
  - `scripts/battle/action_resolver.gd`
  - `scripts/ai_controller.gd`
- Acceptance Criteria:
  1. Grasp creates a follow-up threat that changes player priorities next turn.
  2. Counterplay exists (mitigate, taunt redirect, cleanse, or interrupt line).
  3. Feedback clearly communicates the consequence state.

#### ENC-003 - Difficulty Behavior Packs
- Priority: P2
- Status: TODO
- Systems/Files:
  - `scripts/battle_manager.gd`
  - `scripts/ai_controller.gd`
- Acceptance Criteria:
  1. Hard mode modifies behavior patterns, not only stat multipliers.
  2. Story/Normal/Hard each show distinct encounter tempo.
  3. Reward scaling remains proportional to actual challenge.

---

### Milestone M5 - Balance and Telemetry (P2)

#### BAL-001 - Combat Telemetry Hooks
- Priority: P2
- Status: TODO
- Systems/Files:
  - `scripts/battle_manager.gd`
  - `scripts/battle_scene.gd`
- Acceptance Criteria:
  1. Capture action pick rate, miss rate, KO source, turn count, and resource starvation events.
  2. Data export is script-friendly for tuning passes.
  3. Telemetry toggle available for debug builds.

#### BAL-002 - Tuning Harness
- Priority: P2
- Status: TODO
- Systems/Files:
  - `scripts/dev/*`
- Acceptance Criteria:
  1. Repeatable scenario sims for 20/50/100 turn samples.
  2. Reports include TTK, incoming DPR, and status uptime by difficulty.
  3. Supports per-ability parameter sweeps.

#### BAL-003 - KPI Targets and Weekly Tuning Cadence
- Priority: P2
- Status: TODO
- Systems/Files:
  - `docs/ROADMAP.md`
  - `docs/AGENT_SWAP.md`
- Acceptance Criteria:
  1. KPI targets defined (turn time, meaningful choices, fail-state clarity).
  2. Weekly tuning checklist documented.
  3. Each tuning pass logs hypothesis -> change -> observed outcome.

---

### Milestone M6 - Quality Gates (P0)

#### QA-001 - GDScript Parse/Runtime Gate
- Priority: P0
- Status: TODO
- Systems/Files:
  - `scripts/dev/check_gdscript_sanity.ps1`
  - optional Godot CLI command docs
- Acceptance Criteria:
  1. All `.gd` edits run sanity script before commit.
  2. If Godot CLI available, headless parse check is mandatory.
  3. Failures block commit and are logged in handoff notes.

#### QA-002 - Combat Smoke Matrix
- Priority: P0
- Status: TODO
- Systems/Files:
  - manual QA checklist doc
- Acceptance Criteria:
  1. Matrix covers each hero, each core action type, each status family, each difficulty.
  2. Includes transition cases: battle start, phase change, reaction, battle end.
  3. Includes UI checks: tooltips, floaters, targeting, menu scroll, LB ready state.

---

## Definition of Done (Global)
A ticket is only DONE when:
1. All acceptance criteria are verified in-game.
2. UI/description text matches actual behavior.
3. No parser/runtime errors are introduced.
4. `docs/AGENT_SWAP.md` has a short entry for what changed and why.

## Current Focus
Next actionable ticket: **CMB-004** (Resolve State Machine Hardening), then **PRE-001**.
