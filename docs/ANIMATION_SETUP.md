<!--
DOC_ID: ANIMATION_SETUP
STATUS: ACTIVE - Battle animation authoring and validation guide
LAST_UPDATED: 2026-02-09
SUPERSEDES: None
SUPERSEDED_BY: None
-->

# Battle Animation Setup Guide

This document defines the required setup for battle attack spritesheets so playback is stable, readable, and easy to tune.

## 1) Frame Layout Contract

Each attack sheet entry in `scripts/battle/battle_renderer.gd` must define:

- `path`
- `hframes`
- `vframes`
- `fps`
- `impact_frame`
- optional `frame_sequence` (ordered frame indexes)
- optional `frame_durations` (seconds per timeline step)
- optional `frame_y_offsets` (per-step baseline correction in pixels)

Rules:

1. Texture width must be divisible by `hframes`.
2. Texture height must be divisible by `vframes`.
3. `impact_frame` must point to a valid frame index.
4. `frame_sequence` values must be in `[0, hframes*vframes - 1]`.
5. `frame_durations` must stay inside `0.03s - 2.0s` per step.

## 2) Anchor/Baseline Rules

Attack playback is bottom-anchored by default:

- Each step uses `offset.y = -frame_h + frame_y_offsets[i]`.
- Keep `frame_y_offsets` close to `0`; use small corrections only.
- If visible vertical zigzag appears, first validate frame cut, then apply tiny y offsets (`-2..+2`) per offending step.

Do not solve jitter by changing actor world position during attack playback.

## 3) Frame Size Policy

- Use integer frame cuts only.
- Prefer power-of-two sheets with evenly packed grids.
- Avoid mixed-frame-size packing inside one sheet.
- Keep feet/baseline at the same pixel row across frames when exporting.

## 4) Playback Timing Conventions

Target language for attack beats:

- Anticipation: short and snappy.
- Impact: held long enough to read the hit.
- Recovery: slower than anticipation.

Reference profile (used now for Kairus):

- `2 anticipation` quick (`0.09s`, `0.09s`)
- `1 impact` held (`1.00s`)
- `2 recover` slower (`0.24s`, `0.28s`)

## 5) Import Settings

For attack spritesheets (Godot import):

- `compress/mode=0` (already used)
- `mipmaps/generate=false`
- preserve alpha (`process/fix_alpha_border=true`)

If blur/bleed appears, verify texture filtering mode and ensure sprite frame sampling remains pixel-aligned.

## 6) Validation Guardrail (Before Enabling a New Sheet)

Validation is enforced in `BattleAnimationController.register_attack_spritesheet()`:

1. Path exists and loads to `Texture2D`.
2. Grid divisibility is valid (`width % hframes == 0`, `height % vframes == 0`).
3. Sequence, impact frame, duration bounds, and offset bounds are legal.

Invalid configs are rejected with warnings and do not register.

## 7) Implemented Passes

1. Kairus
- Attack grid corrected to `4x4` (from invalid `4x3` slicing on a `1024x1024` sheet).
- Attack timeline simplified to 5-beat sequence.

2. Ludwig (proving pass)
- Added timeline-config attack entry using current sprite asset.
- Uses same sequence/duration contract to validate non-Kairus integration path.

## 8) Follow-up Tasks

1. Author dedicated attack sheets for Ludwig, Ninos, and Catraca using this exact contract.
2. Add per-character `frame_y_offsets` only after in-game frame-by-frame visual checks.
3. Build a tiny debug overlay to show current attack frame index and step duration while playtesting.
