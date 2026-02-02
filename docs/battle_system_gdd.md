Tales of Sanctuary - Battle System Design Document
BR-006: Marcus Gelt Boss Battle (SNES FF4 Style)

1. BATTLE CONTEXT
1.1 Scene Setup
Location: Stone-walled staging room carved into mountainside mine
Environment Details:

Rough-hewn stone walls with iron support beams
Weapon racks and supply crates scattered throughout
Single oil lantern casting flickering shadows
Narrow passage leading deeper into mine (blocked by boss)

Narrative Entry:
The party breaches through the outer defenses into what appears to be a staging area for mine workers. As they catch their breath, a massive figure emerges from the shadows ahead—Marcus Gelt, veteran soldier turned lieutenant of the mine's master.
His body is encased in what looks like living armor—black, oily material that ripples and shifts like liquid shadow, forming plates and tendrils that coil around his frame. He hefts a massive greataxe, its blade gleaming with dark energy.
"You're trespassing on private property. The Collector always gets his due."
Victory Condition: Reduce Marcus Gelt to 0 HP
Defeat Condition: All 4 party members reach 0 HP
Campaign Tone Notes:

High adventure with emotional weight
Can shift between dramatic tension and lighter moments
Boss should feel threatening but not oppressively dark
Victory should feel earned, not cheap


2. CORE BATTLE SYSTEM
2.1 Turn System Architecture
Turn Order Determination:

Pure turn-based system (no real-time elements)
Turn order calculated at start of each round based on SPD stat
Formula: Turn Priority = SPD + Random(0-5)
Turn order displayed in UI queue (right side of screen)
Order recalculates each round

Action Resolution:

Player selects command for active character
Game validates action legality (MP cost, resource availability)
Action executes immediately
Effects apply (damage, status, buffs)
UI updates (HP bars, status icons, message log)
Next character in turn order becomes active

No Real-Time Pressure:

Player has unlimited time to select actions
No ATB gauge filling
No time-based bonuses/penalties

2.2 Core Stats System
Primary Stats (All Characters):
HP  (Hit Points)     - Health pool, 0 = KO
MP  (Magic Points)   - Spell casting resource
ATK (Attack Power)   - Physical damage modifier
DEF (Defense)        - Physical damage reduction
MAG (Magic Power)    - Spell damage/healing modifier  
SPD (Speed)          - Turn order priority

Derived Stats:
Physical Evasion = Base 5% (can be modified by abilities)
Magic Resistance = MAG stat / 10 (percentage reduction)
Critical Rate    = Base 5% (can be modified by abilities)

2.3 Damage Calculation
Physical Damage Formula:
Base Damage = (Attacker ATK × Attack Multiplier) - (Defender DEF × 0.5)
Variance    = Base Damage × Random(0.90 to 1.10)
Critical    = Variance × 2.0
Final       = Variance (or Critical if triggered)

Example:
Kairus attacks Marcus Gelt
- Kairus ATK: 62
- Attack Multiplier: 1.0 (basic attack)
- Marcus DEF: 55

Base = (62 × 1.0) - (55 × 0.5) = 62 - 27.5 = 34.5
Variance = 34.5 × Random(0.90-1.10) = 31-38 damage
If Crit (5% chance): 62-76 damage

Magic Damage Formula:
Base Damage = (Spell Base Power + (Caster MAG × Spell Multiplier)) - (Target MAG × 0.3)
Variance    = Base Damage × Random(0.95 to 1.05)
Final       = Max(Variance, 1) [Cannot deal 0 damage]

Example:
Catraca casts Fire Bolt on Marcus Gelt
- Spell Base: 20
- Catraca MAG: 68
- Spell Multiplier: 0.5
- Marcus MAG: 35

Base = (20 + (68 × 0.5)) - (35 × 0.3) = (20 + 34) - 10.5 = 43.5
Variance = 43.5 × Random(0.95-1.05) = 41-46 damage

Healing Formula:
HP Restored = Spell Base Heal + (Caster MAG × Heal Multiplier)
Variance    = Base × Random(0.95 to 1.05)
Final       = Round(Variance)

Elemental Modifiers:
Weak to Element:     Damage × 1.5
Resistant to Element: Damage × 0.5
Immune to Element:   Damage = 0
Absorbs Element:     Damage × -1.0 (heals target)

2.4 Action Types & Tags
Action Type Tags (For System Processing):
[PHYSICAL]   - Uses ATK stat, affected by DEF
[MAGICAL]    - Uses MAG stat, affected by magic resistance
[HYBRID]     - Uses both ATK and MAG in calculation
[HEALING]    - Restores HP
[BUFF]       - Positive status/stat modifier
[DEBUFF]     - Negative status/stat modifier
[STATUS]     - Applies status condition
[RESOURCE]   - Consumes non-MP resource (Ki, Superiority Dice, etc.)
[INSTANT]    - Resolves immediately, no animation delay
[TOGGLE]     - On/off state that persists until changed
[SELF]       - Only targets user
[SINGLE]     - Targets one entity
[ALL_ENEMIES] - Targets all enemies
[ALL_ALLIES]  - Targets all allies
[RANDOM]     - Targets random entity in category

Example Action Definition:
{
  "name": "Flurry of Blows",
  "tags": ["PHYSICAL", "RESOURCE", "SINGLE"],
  "resource_type": "Ki",
  "resource_cost": 2,
  "hit_count": 2,
  "damage_multiplier": 1.0,
  "targeting": "single_enemy"
}
```

### 2.5 Status Effects System

**Status Effect IDs & Behaviors:**
```
POISON
- Duration: 3 turns (counts down at end of afflicted's turn)
- Effect: Take 10 damage at end of turn
- Tags: [NEGATIVE, DOT, CLEANSABLE]
- Removed by: Healing items, Ninos Limit Break, battle end

STUN  
- Duration: 1 turn (afflicted loses their next action)
- Effect: Skip turn, cannot act
- Tags: [NEGATIVE, CROWD_CONTROL, CLEANSABLE]
- Removed by: Time expiration, specific cleanse abilities

REGEN
- Duration: 4 turns
- Effect: Restore 15 HP at end of turn
- Tags: [POSITIVE, HOT]
- Removed by: Battle end, time expiration

ATK_UP
- Duration: 3 turns
- Effect: ATK stat × 1.25
- Tags: [POSITIVE, STAT_BUFF]
- Stacks: Can stack up to 2 times (max ATK × 1.5)

ATK_DOWN
- Duration: 3 turns  
- Effect: ATK stat × 0.75
- Tags: [NEGATIVE, STAT_DEBUFF]
- Stacks: Does not stack

DEF_UP
- Duration: 3 turns
- Effect: DEF stat × 1.5
- Tags: [POSITIVE, STAT_BUFF]

GUARD_STANCE
- Duration: Until toggled off
- Effect: DEF × 1.5, Damage taken × 0.5, Enable Riposte passive
- Tags: [TOGGLE, STANCE]
- Special: Character cannot use Attack or special actions while active

FIRE_IMBUE
- Duration: Until toggled off
- Effect: Physical attacks deal +1d4 fire damage (3-7 additional damage)
- Tags: [TOGGLE, ELEMENTAL]
- Resource: Costs 1 Ki per turn active (deducted at end of turn)

CHARM
- Duration: 1 turn
- Effect: Enemy loses next action (similar to Stun)
- Tags: [NEGATIVE, CROWD_CONTROL, MENTAL]
```

**Status Icon Priority (Display Order):**
```
1. Stun/Charm (red icon)
2. Poison (purple icon)
3. Regen (green icon)
4. ATK_UP/ATK_DOWN (orange icon)
5. DEF_UP (blue icon)
6. Stance indicators (yellow icon)
```

### 2.6 Resource Systems

**Resource Types:**
```
MP (Magic Points)
- Regeneration: None during battle (only items/rest restore)
- Max varies by character
- Tracks remaining/max on UI

Ki Points (Kairus only)
- Max: 6
- Regeneration: Full restore on battle end
- Individual ability costs vary (1-3 points)
- Tracks remaining/max on UI

Superiority Dice (Ludwig only)
- Max: 4 uses
- Regeneration: Full restore on battle end
- Each use consumes 1 die, rolls 1d8 for effect value
- Tracks remaining/max on UI (shows number, not die faces)

Bardic Inspiration (Ninos only)
- Max: 4 uses
- Regeneration: Full restore on battle end
- Each use consumes 1 inspiration, grants 1d8 bonus
- Tracks remaining/max on UI

Sorcery Points (Catraca only)
- Max: 5
- Regeneration: Full restore on battle end
- Used to modify spell casting
- Tracks remaining/max on UI

Limit Break Gauge (All Characters)
- Fills by taking damage: +1% per 5 HP damage taken
- Fills by dealing damage: +1% per 10 damage dealt
- Max: 100%
- Regeneration: Persists between battles
- Triggers: Manual activation when full
```

### 2.7 Command Menu Structure

**Universal Menu Layout:**
```
┌─────────────────┐
│ > Attack        │  [Always available unless stunned/charmed]
│   [Unique Cmd]  │  [Character-specific, varies]
│   Magic         │  [Only if character has spells]
│   Item          │  [Always available]
└─────────────────┘
```

**Menu Navigation:**
- D-Pad Up/Down: Move cursor
- A Button: Select/Confirm
- B Button: Cancel/Go back
- No menu wrapping (cursor stops at top/bottom)

**Submenu Depth:**
```
Main Menu → Unique Command → Ability List → Target Selection → Confirm
         → Magic → Spell List → Target Selection → Confirm
         → Item → Item List → Target Selection → Confirm
```

---

## 3. PARTY CHARACTER SPECIFICATIONS

### 3.1 KAIRUS - Elemental Monk

**Role:** High-speed physical DPS with elemental augmentation  
**Archetype:** Glass cannon striker

#### 3.1.1 Base Stats (Level 6)
```
HP:  450
MP:  60
ATK: 62
DEF: 42  
MAG: 28
SPD: 55 (Highest in party)

Ki Points: 6 (max)
Limit Break: Inferno Fist
```

#### 3.1.2 Command Menu
```
┌─────────────────┐
│ > Attack        │
│   Ki Arts       │
│   Imbue         │  
│   Item          │
└─────────────────┘
```

#### 3.1.3 Abilities

**Attack** `[PHYSICAL] [SINGLE]`
```
Name: Unarmed Strike
Target: Single enemy
Cost: 0 MP, 0 Ki
Damage: ATK × 1.0 (Base: ~35-40 damage vs Marcus)
Tags: [PHYSICAL, SINGLE]
Special: If FIRE_IMBUE active, adds 1d4 fire damage (3-7)
Animation: Quick punch combo
```

**Ki Arts Submenu:**
```
Flurry of Blows
Cost: 2 Ki
Tags: [PHYSICAL, RESOURCE, SINGLE]
Effect: Attack target twice in one action
Damage: ATK × 1.0 per hit (2 separate damage calculations)
Special: Each hit can independently trigger FIRE_IMBUE bonus
Animation: Rapid 6-punch combo, 2 hits register damage
Notes: Most reliable DPS option, use when Ki is available
```
```
Stunning Strike  
Cost: 1 Ki
Tags: [PHYSICAL, RESOURCE, SINGLE, STATUS]
Effect: Attack + 50% chance to apply STUN (1 turn)
Damage: ATK × 1.0
Status Check: Random(1-100) ≤ 50 = Success
Animation: Uppercut with golden impact flash
Notes: Save for Phase 3 to interrupt boss ultimate
```
```
Step of the Wind
Cost: 1 Ki
Tags: [RESOURCE, SELF, BUFF]
Effect: Apply DEF_UP (DEF × 1.5) for 2 turns
Special: Next incoming attack has 100% evasion
Animation: Blur effect, Kairus glows blue
Notes: Emergency defensive tool
```
```
Focused Aim
Cost: 1-3 Ki (player chooses amount)
Tags: [RESOURCE, SELF, BUFF]
Effect: Increase critical hit rate based on Ki spent
  - 1 Ki: +15% crit (total 20%)
  - 2 Ki: +30% crit (total 35%)
  - 3 Ki: +45% crit (total 50%)
Duration: Next attack only
Animation: Charging stance, fists glow brighter per Ki spent
Notes: Pair with Ninos Inspire Attack for guaranteed big hit
```

**Imbue Submenu (Toggle System):**
```
Fire Imbue [TOGGLE]
Cost: 1 Ki per turn (deducted at end of Kairus's turn)
Tags: [TOGGLE, ELEMENTAL, SELF]
Effect: FIRE_IMBUE status applied
  - All physical attacks deal +1d4 fire damage (3-7)
  - Fists glow orange/red
  - VFX: Fire trails on attacks
Toggle Off: Select "Fire Imbue" again, status removed
Notes: Keep active most of fight, toggle off when Ki < 3
```
```
Imbue Off
Cost: 0
Effect: Remove FIRE_IMBUE status, stop Ki drain
Notes: Select same menu option to toggle
```

#### 3.1.4 Passive Abilities
```
Patient Defense
Tags: [PASSIVE, DEFENSIVE]
Effect: 15% chance to evade physical attacks
Proc Check: Random(1-100) ≤ 15
Animation: Quick sidestep, attack whiffs
Notes: Always active, no player input
```

#### 3.1.5 Limit Break
```
Inferno Fist
Cost: 100% Limit Gauge
Tags: [PHYSICAL, MAGICAL, SINGLE]
Effect: 5-hit combo, final hit guaranteed critical
Damage Calculation:
  - Hits 1-4: (ATK × 0.8) + 1d6 fire each
  - Hit 5: (ATK × 2.0) + 4d6 fire [CRITICAL FLAG: TRUE]
Total Average: ~280-320 damage
Target: Single enemy
Animation: 
  1. Screen flash, Kairus teleports behind target
  2. 4 rapid fire punches (small damage numbers)
  3. Camera zoom, charging fist
  4. Explosive uppercut (large damage number)
  5. Enemy launched upward, fire explosion
Duration: ~5 seconds
```

#### 3.1.6 Strategic Notes
- **Primary Role:** Consistent physical DPS
- **Resource Management:** Keep Fire Imbue active, use Flurry when Ki allows
- **Phase 1-2:** Spam Attack/Flurry, build Limit gauge
- **Phase 3:** Save Ki for Stunning Strike to interrupt boss ultimate
- **Synergy:** Benefits most from Ninos Inspire Attack, Ludwig Rally

---

### 3.2 LUDWIG VON TANNHAUSER - Shield Knight

**Role:** Tank / Counter-attacker / Support  
**Archetype:** Defensive anchor

#### 3.2.1 Base Stats (Level 6)
```
HP:  580 (Highest in party)
MP:  40
ATK: 58
DEF: 65 (Highest in party)
MAG: 22
SPD: 34 (Slowest in party)

Superiority Dice: 4 (max)
Limit Break: Dragonfire Roar
```

#### 3.2.2 Command Menu
```
┌─────────────────┐
│ > Attack        │
│   Maneuvers     │
│   Guard         │
│   Item          │
└─────────────────┘
```

#### 3.2.3 Abilities

**Attack** `[PHYSICAL] [SINGLE]`
```
Name: Longsword Strike
Target: Single enemy
Cost: 0 MP, 0 Dice
Damage: ATK × 1.2 (Base: ~45-52 damage vs Marcus)
Tags: [PHYSICAL, SINGLE]
Animation: Overhead slash
Notes: Cannot use while GUARD_STANCE active
```

**Maneuvers Submenu:**
```
Lunging Attack
Cost: 1 Superiority Die
Tags: [PHYSICAL, RESOURCE, SINGLE]
Effect: Attack + bonus damage
Damage: (ATK × 1.2) + 1d8 (roll ranges 1-8)
Example: Base 50 + roll 6 = 56 total damage
Target: Single enemy
Animation: Long thrust, sword glows
Notes: Reliable damage boost, use on high-HP targets
```
```
Precision Strike
Cost: 1 Superiority Die  
Tags: [PHYSICAL, RESOURCE, SINGLE]
Effect: Attack with 100% hit rate + bonus damage
Damage: (ATK × 1.2) + 1d8
Special: Ignores evasion mechanics, always hits
Animation: Careful aimed strike, targeting reticle appears
Notes: Use when attack must land (low HP enemy)
```
```
Shield Bash
Cost: 1 Superiority Die
Tags: [PHYSICAL, RESOURCE, SINGLE, STATUS]
Effect: Attack + 40% chance to STUN (1 turn)
Damage: ATK × 1.0 (lower than sword, ~38-45)
Status Check: Random(1-100) ≤ 40
Animation: Forward ram with shield, metallic clang
Notes: Worse than Kairus stun (50%), but Ludwig's option
```
```
Rally
Cost: 1 Superiority Die
Tags: [RESOURCE, HEALING, SINGLE]
Effect: Target ally heals for 1d8 + 5 HP (6-13 HP)
Target: Any ally (including self)
Animation: Ludwig shouts, target glows gold briefly
Notes: Emergency heal, worse than Ninos but doesn't use MP
```

**Guard Command (Toggle System):**
```
Guard Stance [TOGGLE]
Cost: 0 (free action to activate/deactivate)
Tags: [TOGGLE, STANCE, SELF, BUFF]
Effect: 
  - Apply GUARD_STANCE status
  - DEF × 1.5 (65 → 97 effective)
  - All incoming damage × 0.5
  - Enable Riposte passive (see below)
Restrictions:
  - Cannot use Attack command
  - Cannot use Maneuvers (except Rally)
  - Can still use Item
Visual: Shield raised, blue aura around Ludwig
Toggle Off: Select "Guard" again while active
Animation: Shield raise (on), shield lower (off)
Duration: Until manually toggled off or stunned
```

#### 3.2.4 Passive Abilities
```
Riposte
Tags: [PASSIVE, CONDITIONAL, PHYSICAL]
Trigger: Enemy attacks Ludwig while GUARD_STANCE active
Effect: 50% chance to counter-attack
Damage: ATK × 0.6 (~23-28 damage)
Proc Check: Random(1-100) ≤ 50 after damage calculation
Animation: Quick sword swipe during enemy attack animation
Notes: 
  - Only active while Guard Stance is on
  - Procs after taking damage
  - Does not consume Ludwig's turn
  - Can proc multiple times per round if attacked multiple times
```
```
Second Wind
Tags: [PASSIVE, AUTO_REVIVE]
Trigger: Ludwig reaches 0 HP for first time in battle
Effect: Auto-revive to 25% max HP (145 HP)
Cooldown: Once per battle
Animation: 
  1. Ludwig collapses
  2. Golden light pulses
  3. Stands back up, breathing heavy
Notes: 
  - Triggers automatically, no player input
  - Does not consume a turn
  - Message: "Ludwig's will to protect keeps him standing!"
```

#### 3.2.5 Limit Break
```
Dragonfire Roar
Cost: 100% Limit Gauge
Tags: [MAGICAL, ALL_ENEMIES, DEBUFF, BUFF]
Effect: 
  1. Apply CHARM to all enemies (skip next turn, 70% chance per enemy)
  2. Apply ATK_UP to all allies (+25% ATK for 3 turns)
Damage: None (pure utility)
Status Check: Random(1-100) ≤ 70 per enemy
Target: All enemies + all allies
Animation:
  1. Dragon helm glows red
  2. Ludwig roars, camera shakes
  3. Fire cone erupts toward enemies
  4. Allies glow orange (ATK buff)
Duration: ~4 seconds
Notes: Best used Phase 2+ when party needs breathing room
```

#### 3.2.6 Strategic Notes
- **Primary Role:** Absorb damage, protect party
- **Guard Usage:** Activate immediately, toggle off only for emergency heals
- **Maneuver Priority:** 
  - Phase 1: Save dice
  - Phase 2: Lunging Attack for damage  
  - Phase 3: Rally if Ninos is low MP
- **Positioning:** Always targets Ludwig first in enemy AI (threat priority)
- **Synergy:** Guard stance + Ninos buffs = unkillable wall

---

### 3.3 NINOS - Sea Bard

**Role:** Support / Healer / Buffer / Utility  
**Archetype:** Jack-of-all-trades support

#### 3.3.1 Base Stats (Level 6)
```
HP:  420
MP:  110 (Second highest)
ATK: 38
DEF: 35
MAG: 52 (Second highest)
SPD: 42

Bardic Inspiration: 4 uses (max)
Limit Break: Siren's Call
```

#### 3.3.2 Command Menu
```
┌─────────────────┐
│ > Attack        │
│   Inspire       │
│   Magic         │
│   Item          │
└─────────────────┘
```

#### 3.3.3 Abilities

**Attack** `[PHYSICAL] [SINGLE]`
```
Name: Shortsword Slash
Target: Single enemy
Cost: 0 MP
Damage: ATK × 0.9 (Base: ~20-25 damage)
Tags: [PHYSICAL, SINGLE]
Animation: Quick slash
Notes: Weakest physical attack, only use if completely out of resources
```

**Inspire Submenu:**
```
Inspire Attack
Cost: 1 Bardic Inspiration use
Tags: [RESOURCE, BUFF, SINGLE]
Effect: Target ally's next attack deals +1d8 damage (1-8 bonus)
Duration: Until target's next attack action (consumed on use)
Target: Single ally
Visual: Musical notes float to target, glow orange
Animation: Ninos strums instrument, notes appear
Notes: Best on Kairus (Flurry = 2 procs) or Catraca (Fireball)
```
```
Inspire Defense
Cost: 1 Bardic Inspiration use
Tags: [RESOURCE, BUFF, SINGLE]
Effect: Target ally's next incoming damage reduced by 1d8 (1-8 reduction)
Duration: Until target takes damage once (consumed on use)
Target: Single ally
Visual: Musical notes float to target, glow blue
Animation: Ninos plays defensive melody
Notes: Emergency save for squishy targets (Catraca)
```
```
Inspire Magic
Cost: 1 Bardic Inspiration use
Tags: [RESOURCE, BUFF, SINGLE]
Effect: Target ally's next spell costs 0 MP
Duration: Until target casts spell (consumed on use)
Target: Single ally (must have Magic command)
Visual: Musical notes float to target, glow purple
Animation: Ninos sings arcane verse
Notes: Best on Catraca for free Fireball
```
```
Song of Rest
Cost: 1 Bardic Inspiration use
Tags: [RESOURCE, BUFF, ALL_ALLIES]
Effect: All allies gain REGEN status (1d6 HP per turn, 3 turns)
  - Roll 1d6 once, all allies heal that amount per turn
  - Example: Roll 4 → all allies heal 4 HP/turn for 3 turns
Duration: 3 turns
Target: All allies
Visual: Musical notes surround entire party, green glow
Animation: Ninos plays soothing melody
Notes: Sustain healing, use early in long fights
```

**Magic Submenu:**

**Offensive Spells:**
```
Vicious Mockery
Cost: 5 MP
Tags: [MAGICAL, SINGLE, DEBUFF]
Effect: Damage + apply ATK_DOWN (-25% ATK, 2 turns)
Damage: 15 + (MAG × 0.3) = ~30-35 damage
Status: Always applies, no check needed
Target: Single enemy
Animation: Ninos taunts, purple wave hits target
Notes: Cheap debuff, use on high-ATK enemies
```
```
Heat Metal
Cost: 8 MP
Tags: [MAGICAL, SINGLE, STATUS]
Effect: Fire damage + if target wears metal armor, skip next turn
Damage: 20 + (MAG × 0.5) = ~45-50 fire damage
Status Check: If (Enemy has "Armor" tag) → STUN for 1 turn
Target: Single enemy
Animation: Target's armor glows red-hot
Notes: Auto-stun vs armored enemies (Marcus qualifies)
```

**Support Spells:**
```
Healing Word
Cost: 6 MP
Tags: [MAGICAL, HEALING, SINGLE, INSTANT]
Effect: Restore 2d4+5 HP (7-13 HP)
Target: Single ally
Animation: Quick golden sparkle
Notes: Cheap emergency heal, use frequently
```
```
Bless
Cost: 10 MP
Tags: [MAGICAL, BUFF, ALL_ALLIES]
Effect: All allies gain +1d4 to attack damage (1-4 bonus) for 3 turns
  - Roll once, applies to all allies' attacks
Duration: 3 turns
Target: All allies
Animation: Holy light descends on party
Notes: Stack with Inspire Attack for huge damage
```
```
Aura of Vitality
Cost: 15 MP
Tags: [MAGICAL, HEALING, SINGLE]
Effect: Apply REGEN (2d6 HP per turn, 4 turns)
  - Rolls healing at end of each target's turn
  - Example: Turn 1: roll 8 HP, Turn 2: roll 5 HP, etc.
Duration: 4 turns
Target: Single ally
Animation: Green healing aura surrounds target
Notes: Best single-target heal, save for Phase 3
```

**Control Spells:**
```
Hypnotic Pattern
Cost: 12 MP
Tags: [MAGICAL, ALL_ENEMIES, STATUS]
Effect: 50% chance per enemy to apply CHARM (skip next turn)
Status Check: Random(1-100) ≤ 50 per target
Target: All enemies
Animation: Swirling colorful pattern appears
Notes: AoE crowd control, doesn't work on bosses in Phase 3
```

#### 3.3.4 Passive Abilities
```
Sailor's Luck
Tags: [PASSIVE, DEFENSIVE]
Effect: 10% chance to evade any attack (physical or magical)
Proc Check: Random(1-100) ≤ 10
Animation: Ninos stumbles, attack misses
Notes: Always active, pure RNG
```
```
Counterspell Sense (Simplified from "Counterspell Reaction")
Tags: [PASSIVE, CONDITIONAL]
Trigger: Enemy casts spell
Effect: 30% chance to automatically cancel enemy spell cast
Proc Check: Random(1-100) ≤ 30 when enemy uses [MAGICAL] ability
Cooldown: Once per battle
Animation: Ninos's hand glows, enemy spell fizzles
Message: "Ninos disrupts the spell with a discordant note!"
Notes: 
  - Automatic, no player input
  - Does not consume Ninos's turn
  - Saves 1 use per battle (procs on first success)
  - Best case: Cancels boss Phase 3 buff
```

#### 3.3.5 Limit Break
```
Siren's Call
Cost: 100% Limit Gauge
Tags: [MAGICAL, HEALING, ALL_ALLIES]
Effect:
  1. All allies heal 80 HP
  2. Remove all negative status effects (POISON, STUN, ATK_DOWN, etc.)
  3. Apply REGEN (15 HP per turn, 3 turns)
Damage: None (pure support)
Target: All allies
Animation:
  1. Screen shifts blue, ocean wave overlay
  2. Ethereal siren figure appears behind Ninos
  3. Wave washes over party
  4. Status icons clear, HP bars refill
Duration: ~6 seconds
Notes: Ultimate "oh shit" button, save for Phase 3
```

#### 3.3.6 Strategic Notes
- **Primary Role:** Keep party alive, amplify damage
- **MP Management:** Healing Word is cheap, use liberally; save Aura of Vitality for Phase 2+
- **Inspiration Priority:**
  - Phase 1: Inspire Attack on Kairus
  - Phase 2: Inspire Magic on Catraca for free Fireball
  - Phase 3: Inspire Defense on whoever is targeted
- **Spell Rotation:** Bless early → Heal as needed → Heat Metal on cooldown
- **Synergy:** Core support, every character benefits from buffs

---

### 3.4 CATRACA - Metamagic Sorcerer

**Role:** Arcane Nuker / Elemental DPS  
**Archetype:** High-risk glass cannon

#### 3.4.1 Base Stats (Level 6)
```
HP:  360 (Lowest in party)
MP:  140 (Highest in party)
ATK: 28 (Lowest)
DEF: 30 (Second lowest)
MAG: 68 (Highest in party)
SPD: 40

Sorcery Points: 5 (max)
Limit Break: Genie's Wrath
```

#### 3.4.2 Command Menu
```
┌─────────────────┐
│ > Attack        │
│   Metamagic     │
│   Magic         │
│   Item          │
└─────────────────┘
```

#### 3.4.3 Abilities

**Attack** `[PHYSICAL] [SINGLE]`
```
Name: [REMOVED - Too weak to ever use]
Replaced with: "Defend" command
  - Skip turn, gain DEF_UP (+50% DEF) until next turn
  - Use when out of MP and need to survive
```

**Metamagic System:**

**How It Works:**
1. Player selects "Metamagic" from main menu
2. Submenu shows Metamagic options available
3. Player selects Metamagic modifier (spends Sorcery Points)
4. Game immediately transitions to Magic submenu
5. Player selects spell to cast
6. Spell is cast with Metamagic applied
7. Both Sorcery Points and MP are consumed

**Metamagic Options:**
```
Quicken Spell
Cost: 2 Sorcery Points
Tags: [METAMAGIC, MODIFIER]
Effect: After casting spell, Catraca can take another action this turn
  - Second action can be: Attack, Item, or another Metamagic+Spell
  - Cannot use 2 Quickens in one turn (stack limit: 1)
Example Turn: Quicken → Fireball → Fire Bolt (cantrip costs 0 MP)
Notes: Most powerful option, use for burst turns
```
```
Twin Spell
Cost: 1 Sorcery Point
Tags: [METAMAGIC, MODIFIER]
Effect: Single-target spell hits 2 targets instead
  - MP cost unchanged
  - Damage calculated separately per target
Restrictions: Only works on [SINGLE] tagged spells
Example: Fire Bolt deals 45 to Enemy A and 43 to Enemy B
Notes: Use when facing multiple targets (not this fight)
```

**Magic Submenu:**

**Cantrips (0 MP Cost):**
```
Fire Bolt
Cost: 0 MP
Tags: [MAGICAL, SINGLE]
Damage: 20 + (MAG × 0.5) = ~54-60 fire damage
Target: Single enemy
Animation: Flaming projectile
Notes: Spam when low MP
```
```
Shocking Grasp
Cost: 0 MP
Tags: [MAGICAL, SINGLE, STATUS]
Damage: 16 + (MAG × 0.4) = ~43-48 lightning damage
Effect: Target cannot use movement abilities next turn (N/A in this fight)
Target: Single enemy (must be in melee range)
Animation: Hand crackles with lightning
Notes: Slightly weaker than Fire Bolt, situational
```
```
Eldritch Blast
Cost: 0 MP
Tags: [MAGICAL, SINGLE]
Damage: 10 + (MAG × 0.3) = ~30-35 force damage
Target: Single enemy
Animation: Purple energy beam
Notes: Force damage (rarely resisted), lowest cantrip damage
```

**Level 1 Spells:**
```
Mage Armor
Cost: 4 MP
Tags: [MAGICAL, SELF, BUFF]
Effect: Apply DEF_UP (DEF × 1.5) for entire battle
  - 30 → 45 effective DEF
Duration: Until battle ends or Catraca is KO'd
Target: Self only
Animation: Shimmering arcane shield appears
Notes: Cast on Turn 1 always, huge survivability boost
```
```
Magic Missile
Cost: 6 MP
Tags: [MAGICAL, SPECIAL]
Effect: Fire 3 darts, each deals 1d4+1 force damage (2-5 per dart)
  - Can split between targets or focus one
  - Always hits (ignores evasion)
Total Damage: 6-15 force damage
Target: 1-3 enemies (player distributes darts)
Animation: 3 glowing purple darts shoot out
Notes: Guaranteed damage, use when low MP
```

**Level 2 Spells:**
```
Flaming Sphere
Cost: 10 MP
Tags: [MAGICAL, SINGLE, STATUS]
Effect: 
  - Turn cast: Deal 2d6 fire damage (~7 average)
  - Apply persistent burning field
  - Subsequent turns: Can move sphere as bonus action (automatic)
    - If moved to enemy: deal 2d6 fire again
Duration: 3 turns after cast
Target: Single enemy per application
Animation: Floating fireball appears, orbits battlefield
Notes: 
  - Automatic damage each turn (no MP cost after cast)
  - Good sustained damage
  - Implementation: At end of each round, sphere auto-targets highest HP enemy
```

**Level 3 Spells:**
```
Fireball
Cost: 18 MP
Tags: [MAGICAL, ALL_ENEMIES]
Damage: 40 + (MAG × 0.8) = ~94-102 fire damage
  - Damage calculated once, applied to all targets
Target: All enemies
Animation: 
  1. Catraca raises hand, small flame appears
  2. Flame grows into large sphere
  3. Launches toward enemies
  4. Massive explosion
Notes: 
  - Highest damage spell
  - Use with Metamagic for game-changing turns
  - Example: Quicken Fireball → Fire Bolt = ~150 total damage in one turn
```

#### 3.4.4 Passive Abilities
```
Arcane Surge
Tags: [PASSIVE, RESOURCE]
Effect: 10% chance per spell cast to refund MP cost
Proc Check: Random(1-100) ≤ 10 after spell resolves
Message: "Arcane energy surges! MP refunded!"
Animation: Purple sparkle around Catraca
Notes: 
  - Pure RNG, cannot be forced
  - Does not work on cantrips (0 MP already)
  - Can proc on Fireball (huge value)
```

#### 3.4.5 Limit Break
```
Genie's Wrath
Cost: 100% Limit Gauge
Tags: [MAGICAL, SELF, BUFF]
Effect: 
  - Visual transformation: Catraca becomes fire elemental
  - Next 3 spells cost 0 MP
  - Next 3 spells deal +50% damage
Duration: Until 3 spells are cast
Target: Self
Animation:
  1. Catraca disappears into smoke
  2. Genie bottle appears, glows intensely
  3. Erupts in flames, fire elemental form emerges
  4. Buff icon appears (shows 3 charges)
Charge Consumption: Each spell cast reduces charges by 1
Notes:
  - Optimal combo: Fireball → Fireball → Fireball = ~450 damage
  - If battle ends before 3 spells used, charges lost
  - Cast Fireball with Quicken for 2 charges in one turn
```

#### 3.4.6 Strategic Notes
- **Primary Role:** Burst damage in critical moments
- **Turn 1:** Always cast Mage Armor for survivability
- **MP Conservation:** Use cantrips when chip damage is fine, save MP for phases 2-3
- **Metamagic Usage:**
  - Phase 1: Save Sorcery Points
  - Phase 2: Quicken + Fireball combo
  - Phase 3: Quicken + Fireball + Fire Bolt for execute damage
- **Positioning:** Stay behind Ludwig, minimize damage taken
- **Synergy:** 
  - Ninos Inspire Magic → Free Fireball (save 18 MP)
  - Ninos Bless → Fireball deals +1d4 bonus damage

---

## 4. BOSS: MARCUS GELT "THE COLLECTOR"

### 4.1 Visual Design

**Physical Description:**
- **Race:** Human male, mid-50s
- **Build:** Burly, muscular, battle-scarred veteran frame
- **Base Gear:** 
  - Worn leather jerkin with metal plates (medieval brigandine style)
  - Chainmail sleeves
  - Heavy boots, gauntlets
  - Faded military surcoat (torn, showing campaign history)
- **Symbiote Armor:** 
  - Black, tar-like substance coating body
  - Ripples and shifts like liquid shadow
  - Forms additional plates over vital areas
  - Tendrils extend from shoulders/back (not Venom tongue, more tentacle-like)
  - Pulses with dark energy when attacking
- **Weapon:** 
  - Large two-handed greataxe
  - Blade wrapped in dark energy tendrils
  - Drips black ichor
- **Face:**
  - Grizzled, scarred
  - Left eye covered by symbiote (black void)
  - Right eye still human (bloodshot, tired)
  - Graying beard, unkempt

**Sprite Design Notes:**
- **Idle Animation:** Armor subtly ripples, tendrils sway
- **Attack Tells:** 
  - Greataxe Slam: Wind-up raise
  - Tendril Lash: Tendrils coil back
  - Battle Roar: Chest expands
  - Phase transitions: Armor spikes grow

### 4.2 Boss Stats
```
Name: Marcus Gelt, The Collector
Type: Humanoid (Boss)
Level: 7

=== BASE STATS ===
HP:  1200 (Total health pool)
MP:  N/A (Does not use MP system)
ATK: 75
DEF: 55
MAG: 35
SPD: 38 (Acts between Ninos/Catraca and Kairus typically)

=== RESISTANCES ===
Physical: Normal (100%)
Fire: Normal (100%)
Lightning: Normal (100%)
Force: Normal (100%)
Poison: Immune (0%)
Stun: 50% resistance (halve duration)

=== PHASE THRESHOLDS ===
Phase 1: 100% - 60% HP (1200 - 720)
Phase 2: 60% - 30% HP (720 - 360)
Phase 3: 30% - 0% HP (360 - 0)
```

### 4.3 Boss Abilities by Phase

#### 4.3.1 Phase 1 (100%-60% HP) - "Testing the Intruders"

**Behavior Pattern:**
```
Turn Rotation (repeats):
1. Greataxe Slam (single target)
2. Tendril Lash (random target)
3. Battle Roar (self-buff)
4. Collector's Grasp (special mechanic)
[Repeat]
```

**Abilities:**
```
Greataxe Slam
Tags: [PHYSICAL, SINGLE]
Target: Highest threat (Ludwig if Guard active, else highest ATK)
Damage: ATK × 1.2 = ~90-110 damage
Animation: 
  1. Marcus raises axe overhead (1 second telegraph)
  2. Slams down with both hands
  3. Ground cracks on impact
Threat Priority: Ludwig > Kairus > Catraca > Ninos
Notes: Standard heavy attack, predictable
```
```
Tendril Lash
Tags: [PHYSICAL, RANDOM, STATUS]
Target: Random party member (true random, equal chance)
Damage: ATK × 0.8 = ~60-75 damage
Effect: Apply POISON (10 damage per turn, 3 turns)
Animation:
  1. Shoulder tendrils extend rapidly
  2. Whip toward target
  3. Purple poison icon appears on target
Status: Always applies POISON, no check
Notes: Main pressure tool, requires healing attention
```
```
Battle Roar
Tags: [SELF, BUFF]
Target: Self
Effect: Apply ATK_UP (+25% ATK) for 4 turns
  - Stacks up to 2 times (max +50% ATK)
  - ATK 75 → 94 (1 stack) → 112 (2 stacks)
Animation:
  1. Marcus pounds chest
  2. Roars loudly, screen shakes
  3. Red aura surrounds him
Notes: Becomes threatening if not countered with debuffs
```
```
Collector's Grasp
Tags: [SPECIAL, SINGLE, FORCED_POSITION]
Target: Random party member (excludes Ludwig if Guard active)
Effect: 
  1. Target is "pulled" to Marcus (narrative, not positional system)
  2. Message: "[Character] is dragged toward Marcus!"
  3. Next turn, Marcus uses Greataxe Slam on pulled target (guaranteed)
  4. Pulled character cannot evade this Slam (bypass evasion passives)
Damage: None on pull, damage comes next turn
Animation:
  1. Tendrils shoot out, wrap around target
  2. Target sprite shakes
  3. Red "target" icon appears above character
Counterplay: 
  - Ludwig can Guard to protect (if he acts before Marcus's next turn)
  - Ninos can Inspire Defense on pulled target
  - Target pulled should use defensive item/ability
Notes: Creates tension, forces resource use
```

**Phase 1 Strategy:**
- Ludwig: Activate Guard Turn 1, maintain throughout
- Kairus: Build damage with Fire Imbue, save Ki for Phase 2
- Ninos: Heal Tendril Lash poison, use Healing Word as needed
- Catraca: Cast Mage Armor Turn 1, spam Fire Bolt, save MP

**Phase Transition Trigger:**
- HP reaches 720 (60%)
- Marcus staggers, symbiote armor pulses violently
- Message: "The symbiote armor awakens fully!"
- Visual: Tendrils become sharper, armor forms spikes
- Turn order resets (new round begins immediately)

#### 4.3.2 Phase 2 (60%-30% HP) - "The Veteran's Fury"

**Behavior Changes:**
- More aggressive, attacks more frequently
- Gains new abilities
- Turn rotation becomes less predictable

**Turn Rotation (repeats):**
```
1. Greataxe Slam
2. Symbiotic Rage (new)
3. [Skip turn - cost of Rage]
4. Tendril Lash
5. Dark Regeneration (new, every ~4-5 turns)
[Repeat from 1]
```

**New Abilities:**
```
Symbiotic Rage
Tags: [PHYSICAL, SINGLE]
Target: Highest HP party member
Effect: Attack target twice in one action
Damage: ATK × 1.0 per hit (~75-90 per hit, ~150-180 total)
Cost: Marcus's next turn is skipped (appears in turn order but auto-passes)
Animation:
  1. Armor spikes extend
  2. Marcus enters berserk stance
  3. Rapid double slash combo
  4. Breathing heavily (visual cue for skipped turn)
Notes: 
  - Devastating if both hits land on squishy targets
  - Ludwig should intercept if Guard active (takes reduced damage)
  - Message next turn: "Marcus catches his breath." [Turn skipped]
```
```
Dark Regeneration
Tags: [SELF, HEALING, CLEANSE]
Target: Self
Effect: 
  - Heal 100 HP
  - Remove all negative status effects (ATK_DOWN, POISON, STUN)
Cooldown: Every 4 turns (tracked internally)
Animation:
  1. Symbiote armor glows purple
  2. Wounds close, ichor flows back into body
  3. Status icons clear from Marcus
Notes:
  - Can be interrupted by Kairus Stunning Strike
  - Priority interrupt target
  - If interrupted, ability is canceled but cooldown still advances
```

**Retained Abilities:**
- Greataxe Slam (unchanged)
- Tendril Lash (unchanged)
- Battle Roar (unchanged)
- Collector's Grasp (removed in Phase 2 - too defensive for aggressive phase)

**Phase 2 Strategy:**
- Ludwig: Maintain Guard, prepare for Symbiotic Rage hits
- Kairus: Use Flurry of Blows aggressively, save 1 Ki for stunning Dark Regeneration
- Ninos: Aura of Vitality on Ludwig (sustain through Rage), use Bless to boost party damage
- Catraca: Fireball for big damage, use Quicken Metamagic for burst turns

**Phase Transition Trigger:**
- HP reaches 360 (30%)
- Marcus roars in pain, symbiote armor fully envelops him
- Message: "The Collector's desperation takes hold!"
- Visual: Entire body covered in black armor, only one eye visible
- All party members' turn order advances (everyone acts before Marcus's next turn)

#### 4.3.3 Phase 3 (30%-0% HP) - "Desperation"

**Behavior Changes:**
- Ultimate ability unlocked
- Faster attacks
- Less healing, more damage output

**Turn Rotation:**
```
1. Venom Strike (Ultimate, every 4 turns)
2. Greataxe Slam
3. Symbiotic Rage
4. [Skip turn]
5. Greataxe Slam
6. Venom Strike
[Repeat]
```

**Ultimate Ability:**
```
Venom Strike
Tags: [MAGICAL, ALL_ALLIES, STATUS, DEBUFF]
Target: All party members
Effect:
  - Deal 120 magic damage to all
  - Apply POISON (10 damage per turn, 3 turns) to all
  - Apply ATK_DOWN (-30% ATK, 3 turns) to all
Damage: Base 120, reduced by each character's MAG stat
  - Ludwig: ~120 - 7 = ~113 damage
  - Kairus: ~120 - 8 = ~112 damage
  - Ninos: ~120 - 15 = ~105 damage
  - Catraca: ~120 - 20 = ~100 damage
Animation:
  1. Marcus raises axe, symbiote drips heavily
  2. Screen darkens, purple fog spreads
  3. Tendrils erupt from ground beneath party
  4. All characters flash with damage
  5. Status icons appear (Poison + ATK Down)
Duration: ~6 seconds
Telegraph: 
  - Turn before Venom Strike: Message appears
  - "Marcus's armor swells ominously... something big is coming!"
  - Gives player 1 full turn to prepare
Counterplay:
  - Ludwig Guard active: Party takes 50% less damage (60 instead of 120)
  - Ninos must have healing ready (Aura of Vitality or Siren's Call)
  - Catraca can use item to heal if low MP
Notes:
  - First use: Turn 2 of Phase 3
  - Second use: Turn 6 of Phase 3 (if battle lasts)
  - Wipe potential if party is low HP
```

**Retained Abilities:**
- Greataxe Slam (damage increased: ATK × 1.3 = ~100-120)
- Symbiotic Rage (unchanged)
- Tendril Lash (removed in Phase 3 - replaced by Venom Strike pressure)

**Phase 3 Strategy:**
- **Critical:** Watch for Venom Strike telegraph
  - Ludwig must be Guarding before Venom Strike turn
  - Ninos should have Aura of Vitality on cooldown or Limit Break ready
  - All characters should be above 50% HP minimum
- Kairus: Use Stunning Strike to interrupt Marcus between Venom Strikes
- Catraca: Save Limit Break for burst damage after surviving first Venom Strike
- Ninos: Emergency Siren's Call if party is critical after Venom Strike

**Victory:**
- HP reaches 0
- Marcus collapses to knees
- Symbiote armor dissolves into smoke
- Final dialogue: *"You... you're just making it worse. He'll take everything from you... just like he took from me."*
- Marcus falls unconscious
- Victory fanfare plays
- Transition to rewards screen

### 4.4 AI Decision Tree (Simplified)

**Phase 1 AI:**
```
IF Turn Count % 4 == 1 THEN
  Action = Greataxe Slam
ELSE IF Turn Count % 4 == 2 THEN
  Action = Tendril Lash
ELSE IF Turn Count % 4 == 3 THEN
  Action = Battle Roar
ELSE IF Turn Count % 4 == 0 THEN
  Action = Collector's Grasp
```

**Phase 2 AI:**
```
IF Turn Count % 5 == 0 AND Dark Regen Available THEN
  Action = Dark Regeneration
ELSE IF Last Action != Symbiotic Rage THEN
  Action = Symbiotic Rage
ELSE IF Last Action == Symbiotic Rage THEN
  Action = Skip Turn
ELSE
  Action = Random(Greataxe Slam, Tendril Lash)
```

**Phase 3 AI:**
```
IF Turn Count % 4 == 0 THEN
  Action = Venom Strike
ELSE IF Turn Count % 4 == 2 THEN
  Action = Symbiotic Rage
ELSE IF Last Action == Symbiotic Rage THEN
  Action = Skip Turn
ELSE
  Action = Greataxe Slam
```

**Targeting Priority:**
```
Greataxe Slam:
  IF Ludwig has GUARD_STANCE THEN
    Target = Ludwig
  ELSE
    Target = Highest ATK stat

Tendril Lash:
  Target = Random(All party members)

Symbiotic Rage:
  Target = Highest Current HP

Collector's Grasp:
  IF Ludwig has GUARD_STANCE THEN
    Target = Random(Kairus, Ninos, Catraca)
  ELSE
    Target = Random(All party members)

Venom Strike:
  Target = All party members (no selection)
```

---

## 5. UI/UX SPECIFICATIONS

### 5.1 Battle Screen Layout
```
┌──────────────────────────────────────────────────────────────────┐
│                       BATTLE SCREEN                              │
│                                                                  │
│  ┌─────────────┐                                ┌─────────────┐ │
│  │  [KAIRUS]   │                                │             │ │
│  │   SPRITE    │                                │  [MARCUS]   │ │
│  │             │                                │   SPRITE    │ │
│  │             │                                │             │ │
│  │  [LUDWIG]   │                                │             │ │
│  │   SPRITE    │                                │             │ │
│  │             │                                └─────────────┘ │
│  │  [NINOS]    │                                               │ │
│  │   SPRITE    │                                               │ │
│  │             │                                ┌────────────┐  │
│  │  [CATRACA]  │                                │ TURN ORDER │  │
│  │   SPRITE    │                                │            │  │
│  │             │                                │  Kairus    │  │
│  └─────────────┘                                │  Marcus    │  │
│                                                  │  Ninos     │  │
│                                                  │  Catraca   │  │
│                                                  │  Ludwig    │  │
│                                                  └────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  MARCUS GELT                    HP: ████████ 1200/1200  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ KAIRUS     HP: 380/450  MP: 42/60  Ki: 4/6  Limit: 67%  │   │
│  │ Status: [FIRE_IMBUE]                                     │   │
│  │                                                          │   │
│  │ > Attack   Ki Arts   Imbue   Item                       │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ MESSAGE LOG:                                             │   │
│  │ > Kairus uses Flurry of Blows!                           │   │
│  │   First hit: 87 damage!                                  │   │
│  │   Second hit: 92 damage!                                 │   │
│  │ > Marcus Gelt uses Tendril Lash on Catraca!              │   │
│  │   Catraca takes 68 damage!                               │   │
│  │   Catraca is POISONED!                                   │   │
│  └──────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

**Layout Specifications:**

**Character Sprites (Left Side):**
- 4 party members stacked vertically
- Each sprite: ~64x64 pixels (SNES scale)
- Spacing: 16 pixels between sprites
- Position: 80 pixels from left edge
- Active character pulses/glows

**Enemy Sprite (Right Side):**
- Boss: ~96x96 pixels (larger than party)
- Position: 400 pixels from left edge, centered vertically
- Idle animation loops

**Turn Order Panel:**
- Position: Top right corner, 520px from left, 80px from top
- Width: 120 pixels, Height: 200 pixels
- Background: Semi-transparent dark box
- Font: Pixel font, 8pt
- Shows next 5 turns
- Active turn highlighted in yellow
- Updates dynamically each turn

**Boss HP Bar:**
- Position: Below enemy sprite, centered
- Width: 280 pixels, Height: 24 pixels
- Shows Name + HP fraction (e.g., "1200/1200")
- Bar color: Red gradient
- Changes color by phase:
  - Phase 1: Red
  - Phase 2: Dark red
  - Phase 3: Purple (symbiote takeover)

**Active Character Panel:**
- Position: Bottom left, 40px from bottom edge
- Width: 500 pixels, Height: 80 pixels
- Shows:
  - Character name
  - HP (current/max with bar)
  - MP (current/max)
  - Resource tracker (Ki/Dice/Inspiration/SP if applicable)
  - Limit Break gauge (percentage bar)
  - Active status icons (max 4 visible, cycle if more)
- Command menu appears below this panel

**Message Log:**
- Position: Bottom center, spans full width minus 80px margins
- Height: 100 pixels
- Shows last 4 messages
- Scrolls up as new messages appear
- Font: Pixel font, 8pt
- Color coded:
  - Player actions: White
  - Enemy actions: Yellow
  - Damage numbers: Red (outgoing), Orange (incoming)
  - Healing: Green
  - Status effects: Purple

### 5.2 Menu Navigation Flow

**Input Mapping (SNES Controller Style):**
```
D-Pad Up/Down:    Navigate menu options
D-Pad Left/Right: (Unused in menus)
A Button:         Confirm/Select
B Button:         Cancel/Back
X Button:         (Unused)
Y Button:         (Unused)
Start:            Open pause menu
Select:           View detailed character stats (battle paused)
```

**Main Command Menu:**
```
Step 1: Player presses A on "Attack"
  → Game executes attack immediately
  → No target selection needed (auto-targets enemy)

Step 2: Player presses A on "Ki Arts"
  → Submenu opens: [Flurry of Blows, Stunning Strike, Step of Wind, Focused Aim]
  → Player navigates with D-Pad, presses A to select ability
  → If ability targets enemy: Auto-target (only 1 enemy)
  → If ability targets ally: Cursor appears over party, D-Pad to select, A to confirm
  → Ability executes

Step 3: Player presses A on "Imbue"
  → Submenu opens: [Fire Imbue, Imbue Off]
  → Player selects, toggle immediately applies
  → Returns to main menu (no turn consumed if only toggling)

Step 4: Player presses B to cancel
  → Backs out one menu level
  → If at main menu, shows "Are you sure?" prompt
```

**Target Selection (Allies):**
```
When ability requires ally target:
1. Cursor appears above first ally sprite (top to bottom)
2. D-Pad Up: Move cursor up
3. D-Pad Down: Move cursor down
4. A: Confirm target
5. B: Cancel, return to ability menu
```

**Confirmation Flow:**
```
After final input (target selected, ability chosen):
1. Small confirmation window appears: "Use [Ability Name] on [Target]?"
2. Options: [Yes] [No]
3. Default selected: Yes
4. A: Confirm and execute
5. B: Cancel and return to target selection
```

### 5.3 Visual Feedback Systems

**Damage Numbers:**
- Appear above target sprite
- Rise upward and fade (1 second duration)
- Size based on damage magnitude:
  - <50 damage: Small font (8pt)
  - 50-100 damage: Medium font (12pt)
  - >100 damage: Large font (16pt)
- Color:
  - Physical: White
  - Fire: Orange
  - Lightning: Yellow
  - Force: Purple
  - Healing: Green
  - Critical: Red, larger, with "CRITICAL!" text

**Status Icons:**
- Appear below character sprite
- Max 4 icons displayed, cycle if more active
- Icon size: 16x16 pixels
- Update every turn
- Icons:
  - POISON: Purple skull
  - STUN: Yellow stars circling
  - REGEN: Green plus sign
  - ATK_UP: Red up arrow
  - ATK_DOWN: Red down arrow
  - DEF_UP: Blue shield
  - GUARD_STANCE: Blue shield (full)
  - FIRE_IMBUE: Orange flame
  - CHARM: Pink heart

**Hit Flash:**
- Target sprite flashes white for 0.1 seconds when hit
- Boss sprite flashes red when hit

**Turn Indicator:**
- Active character: White glow around sprite
- Active character panel: Yellow border

**Low HP Warning:**
- When character drops below 30% HP:
  - HP bar flashes red
  - Sprite flashes red every 2 seconds
  - Warning sound plays once

**Phase Transition Effects:**
- Screen shake (0.5 seconds)
- Boss sprite grows slightly
- Color overlay (red → dark red → purple)
- Sound cue (ominous sting)
- Message: "[Phase Name]"

---

## 6. BATTLE FLOW & VICTORY CONDITIONS

### 6.1 Battle Initialization

**Pre-Battle Setup:**
1. Load battle scene background (stone room)
2. Position character sprites (left side, stacked)
3. Position boss sprite (right side)
4. Initialize all stats to character base values
5. Roll initiative for turn order (SPD + Random(0-5))
6. Display turn order panel
7. Play battle intro music
8. Show message: "Marcus Gelt blocks your path!"
9. Camera pans from party to boss, then back to party
10. First character's turn begins

### 6.2 Turn Flow

**Per-Turn Sequence:**
```
1. Check turn order queue
2. Advance to next character
3. IF character is player-controlled:
     a. Highlight character sprite
     b. Display character panel (HP/MP/Resources)
     c. Open command menu
     d. Wait for player input
     e. Execute selected action
     f. Apply effects (damage, status, etc.)
     g. Update UI (HP bars, status icons)
     h. Message log updates
   ELSE (character is AI-controlled):
     a. AI selects action based on decision tree
     b. Execute action
     c. Apply effects
     d. Update UI
     e. Message log updates

4. Check for status effect triggers (end-of-turn damage/healing)
5. Check for victory/defeat conditions
6. IF battle continues:
     Return to step 1
   ELSE:
     Proceed to victory/defeat sequence
```

### 6.3 Victory Conditions

**Player Victory:**
- Trigger: Marcus Gelt HP reaches 0
- Sequence:
  1. Boss sprite flashes white rapidly (0.5 seconds)
  2. Boss sprite falls to knees (animation)
  3. Symbiote armor dissolves (particle effect, 2 seconds)
  4. Final dialogue box appears:
```
     Marcus Gelt: "You... you're just making it worse. 
                   He'll take everything from you... 
                   just like he took from me."
```
  5. Boss sprite fades out (1 second)
  6. Victory fanfare plays (FF victory theme style)
  7. Party sprites jump/cheer animation
  8. Fade to black
  9. Rewards screen appears

**Defeat Condition:**
- Trigger: All 4 party members reach 0 HP
- Sequence:
  1. Last character sprite collapses
  2. Screen fades to gray
  3. "Defeat" text appears (red, large)
  4. Defeat music plays (somber tune)
  5. Options: [Retry] [Return to Camp]
     - Retry: Restart battle from Turn 1, all stats reset
     - Return to Camp: Exit to overworld (future implementation)

**Special Conditions:**
- If Ludwig's Second Wind procs, message: "Ludwig refuses to fall!"
- If Ninos's Siren's Call saves party from wipe, message: "The Siren's song revives hope!"

### 6.4 Rewards Screen
```
┌─────────────────────────────────────┐
│           VICTORY!                  │
│                                     │
│   Marcus Gelt Defeated              │
│                                     │
│   EXP Gained:  1200                 │
│   Gil Gained:  850                  │
│                                     │
│   Items Found:                      │
│   • Symbiote Shard (x1)             │
│   • Potion (x2)                     │
│                                     │
│   [Press A to Continue]             │
└─────────────────────────────────────┘
```

**Rewards Distribution:**
- EXP split evenly among all party members
- Gil added to party total (shared currency)
- Items added to inventory

**Rare Drop Check:**
```
On victory:
  Roll 1d100
  IF roll ≤ 10 THEN
    Add "Collector's Greataxe" to drops
    Message: "You found a rare item!"

Post-Battle:

Party HP/MP persist (do not auto-restore)
Status effects cleared
Resources reset (Ki, Superiority Dice, Bardic Inspiration, Sorcery Points)
Limit Break gauges persist
Transition to post-battle dialogue or next scene


7. ASSET REQUIREMENTS
7.1 Sprite Assets
Character Sprites (Battle Stance):

Kairus: Monk in fighting pose, fists raised

Idle: Breathing animation, subtle stance shift
Attack: 5-frame punch combo
Hit: 2-frame recoil
KO: Collapse to knees
Victory: Fist pump, grin


Ludwig: Knight with shield forward, sword ready

Idle: Shield subtle movement, breathing
Attack: 4-frame sword slash
Guard: Shield raised (different pose)
Hit: 2-frame blocked/absorbed
KO: Falls backward, shield drops
Victory: Sword raised high


Ninos: Bard with instrument (drum), casual stance

Idle: Instrument sway, foot tap
Attack: 3-frame quick slash (not focus)
Cast: 3-frame playing instrument
Hit: 2-frame stumble
KO: Sits down, instrument drops
Victory: Plays victory tune


Catraca: Sorcerer in robed stance, hand raised

Idle: Robe flutter, hand glow
Attack: (Use "Defend" pose instead)
Cast: 4-frame spell gesture (varies by element)
Hit: 2-frame recoil
KO: Collapses forward
Victory: Arms raised, sparkles



Boss Sprite (Marcus Gelt):

Base size: 96x96 pixels
Idle: Armor ripple, tendril sway (loop)
Attack: 5-frame greataxe swing
Special attacks:

Tendril Lash: 4-frame whip extension
Battle Roar: 3-frame chest pound
Symbiotic Rage: 6-frame double slash
Dark Regeneration: 4-frame healing pulse
Venom Strike: 8-frame ultimate windup


Hit: 2-frame flash white
Phase transitions:

Phase 2: Armor spikes grow (3-frame morph)
Phase 3: Full body coverage (4-frame transform)


Defeat: 6-frame collapse + dissolve particles

7.2 VFX Assets
Attack Effects:

Slash trails (sword, axe): White arc sprite
Punch impacts: Circular burst, yellow/orange
Fire trail (Kairus imbue): Orange flame particles
Lightning (Shocking Grasp): Jagged bolts, yellow
Force beam (Eldritch Blast): Purple energy ray

Spell Effects:

Fire Bolt: Fireball projectile, orange flame, 16x16px
Fireball: Large explosion, 64x64px, expanding circle
Flaming Sphere: Floating fireball, 24x24px, orbital trail
Shocking Grasp: Hand crackle, lightning tendrils
Healing Word: Golden sparkles, upward float
Bless: Holy light beams, downward rays
Aura of Vitality: Green healing aura, pulsing ring
Hypnotic Pattern: Swirling rainbow colors, screen overlay
Mage Armor: Shimmer effect, blue outline on Catraca

Status Effects:

Poison cloud: Purple smoke particles
Stun stars: Yellow stars circling head
Buff glow: Color-coded aura (red ATK, blue DEF, green HP)
Guard stance: Blue shield overlay
Fire Imbue: Orange flame flicker on fists

Environmental:

Hit flash: White screen flash, 0.1 sec
Screen shake: 3-pixel displacement, 0.5 sec
Phase transition: Screen darkens, red/purple overlay

7.3 Audio Assets
Music Tracks:

Battle theme (looping): Orchestral, intense, 2-3 minute loop

Phase 1: Standard battle music
Phase 2: Music intensifies (add drum layer)
Phase 3: Music becomes desperate (add choir)


Victory fanfare: 10-second FF-style celebration theme
Defeat theme: 8-second somber strings

Sound Effects:

Menu navigation: Cursor beep (short blip)
Menu confirm: Chime (higher pitch)
Menu cancel: Buzz (lower pitch)
Attack whoosh: Sword slash, punch impact
Hit impact: Thud, metallic clang
Magic cast: Ethereal chime, varies by element
Fire spell: Whoosh + crackle
Lightning spell: Zap + crackle
Healing: Soft bell chime
Status applied: Pop (buff), hiss (debuff)
Critical hit: Explosion sound
Boss roar: Deep growl
Phase transition: Ominous sting, low rumble
Victory: Cheer sound, fanfare
Defeat: Collapse thud, sad music

7.4 UI Assets
Menus:

Command menu box: 9-slice scalable panel, stone texture
Cursor: Yellow arrow, 16x16px, pointing right
HP bar: Red gradient, 3px height
MP bar: Blue gradient, 3px height
Resource bars (Ki/Dice/etc.): Gold gradient
Limit gauge: Rainbow gradient (fills left to right)

Icons:

Status effect icons: 16x16px each (see section 5.3)
Item icons: 16x16px (potion, etc.)
Character portraits: 32x32px (for turn order panel)

Fonts:

Main UI: Pixel font, 8pt (menus, stats)
Dialogue: Pixel font, 8pt (message log)
Damage numbers: Bold pixel font, variable size

Backgrounds:

Battle background: Stone-walled room

Rough stone texture
Iron support beams
Weapon rack in background
Flickering lantern (animated light)
Narrow passage (blurred out, depth)




8. TECHNICAL IMPLEMENTATION NOTES
8.1 State Management
Battle State Object:
BattleState = {
  phase: 1,  // 1, 2, or 3
  turn_count: 0,
  active_character: null,  // Reference to current actor
  
  party: [
    {
      id: "kairus",
      hp_current: 450,
      hp_max: 450,
      mp_current: 60,
      mp_max: 60,
      ki_current: 6,
      ki_max: 6,
      limit_gauge: 0,
      status_effects: [],
      stats: { atk: 62, def: 42, mag: 28, spd: 55 }
    },
    // ... Ludwig, Ninos, Catraca
  ],
  
  enemies: [
    {
      id: "marcus_gelt",
      hp_current: 1200,
      hp_max: 1200,
      status_effects: [],
      stats: { atk: 75, def: 55, mag: 35, spd: 38 },
      phase: 1,
      ability_cooldowns: { dark_regen: 0 }
    }
  ],
  
  turn_order: [],  // Array of character/enemy IDs sorted by SPD
  message_log: [],  // Last 4 messages
  
  flags: {
    ludwig_second_wind_used: false,
    ninos_counterspell_used: false,
    // ... other one-time flags
  }
}

Turn Order Calculation:
function calculateTurnOrder(battle_state) {
  let turn_queue = [];
  
  // Add all party members
  for (char of battle_state.party) {
    if (char.hp_current > 0 && !hasStatus(char, "STUN")) {
      turn_queue.push({
        id: char.id,
        priority: char.stats.spd + random(0, 5)
      });
    }
  }
  
  // Add all enemies
  for (enemy of battle_state.enemies) {
    if (enemy.hp_current > 0) {
      turn_queue.push({
        id: enemy.id,
        priority: enemy.stats.spd + random(0, 5)
      });
    }
  }
  
  // Sort by priority (descending)
  turn_queue.sort((a, b) => b.priority - a.priority);
  
  return turn_queue.map(entry => entry.id);
}

8.2 Action Resolution Pipeline
When player selects an ability:
function executeAction(actor, action, targets) {
  // 1. Validate action legality
  if (!canUseAction(actor, action)) {
    showMessage("Cannot use " + action.name + "!");
    return;
  }
  
  // 2. Consume resources
  consumeResources(actor, action);
  
  // 3. Play animation
  playAnimation(actor, action.animation_id);
  
  // 4. Calculate effects
  let results = calculateActionEffects(actor, action, targets);
  
  // 5. Apply effects to targets
  for (result of results) {
    applyDamage(result.target, result.damage);
    applyStatus(result.target, result.statuses);
    showDamageNumber(result.target, result.damage);
  }
  
  // 6. Update UI
  updateHPBars();
  updateStatusIcons();
  
  // 7. Log message
  addMessage(actor.name + " uses " + action.name + "!");
  
  // 8. Check for triggers (passives, counterattacks)
  checkPassiveTriggers(actor, action, targets, results);
  
  // 9. Check victory/defeat
  if (checkVictoryCondition()) {
    triggerVictory();
  } else if (checkDefeatCondition()) {
    triggerDefeat();
  }
}

Damage Calculation Implementation:
function calculatePhysicalDamage(attacker, defender, multiplier) {
  let base = (attacker.stats.atk * multiplier) - (defender.stats.def * 0.5);
  let variance = base * random(0.90, 1.10);
  
  // Check for critical
  let crit_chance = 5; // Base 5%
  if (hasBuff(attacker, "FOCUSED_AIM")) {
    crit_chance += attacker.focused_aim_bonus;
  }
  
  if (random(0, 100) <= crit_chance) {
    variance *= 2.0;
    showCriticalIndicator();
  }
  
  // Apply elemental bonuses
  if (hasStatus(attacker, "FIRE_IMBUE")) {
    variance += rollDice(1, 4);  // +1d4 fire
  }
  
  return Math.max(1, Math.floor(variance));
}

8.3 Status Effect System
Status Effect Data Structure:
StatusEffect = {
  id: "POISON",
  duration: 3,  // Turns remaining
  value: 10,    // Damage per turn (if applicable)
  tags: ["NEGATIVE", "DOT", "CLEANSABLE"]
}

Status Processing (End of Turn):
function processEndOfTurnEffects(character) {
  for (status of character.status_effects) {
    if (status.tags.includes("DOT")) {
      applyDamage(character, status.value);
      showMessage(character.name + " takes " + status.value + " poison damage!");
    }
    
    if (status.tags.includes("HOT")) {
      healCharacter(character, status.value);
      showMessage(character.name + " recovers " + status.value + " HP!");
    }
    
    // Decrement duration
    status.duration -= 1;
    
    // Remove if expired
    if (status.duration <= 0) {
      removeStatus(character, status.id);
      showMessage(status.id + " wears off!");
    }
  }
  
  // Process resource drains (Fire Imbue Ki cost)
  if (hasStatus(character, "FIRE_IMBUE") && character.id == "kairus") {
    character.ki_current -= 1;
    if (character.ki_current < 0) {
      removeStatus(character, "FIRE_IMBUE");
      showMessage("Kairus's Fire Imbue fades (out of Ki)!");
    }
  }
}
8.4 AI Behavior
Boss AI Implementation:
function getBossAction(boss, battle_state) {
  let action = null;
  
  // Phase 1 AI
  if (boss.phase == 1) {
    let turn_mod = battle_state.turn_count % 4;
    if (turn_mod == 1) action = "greataxe_slam";
    if (turn_mod == 2) action = "tendril_lash";
    if (turn_mod == 3) action = "battle_roar";
    if (turn_mod == 0) action = "collectors_grasp";
  }
  
  // Phase 2 AI
  if (boss.phase == 2) {
    if (boss.ability_cooldowns.dark_regen == 0 && battle_state.turn_count % 5 == 0) {
      action = "dark_regeneration";
      boss.ability_cooldowns.dark_regen = 4;
    } else if (boss.last_action != "symbiotic_rage") {
      action = "symbiotic_rage";
    } else if (boss.last_action == "symbiotic_rage") {
      action = "skip_turn";
    } else {
      action = random(["greataxe_slam", "tendril_lash"]);
    }
  }
  
  // Phase 3 AI
  if (boss.phase == 3) {
    if (battle_state.turn_count % 4 == 0) {
      action = "venom_strike";
    } else if (battle_state.turn_count % 4 == 2) {
      action = "symbiotic_rage";
    } else if (boss.last_action == "symbiotic_rage") {
      action = "skip_turn";
    } else {
      action = "greataxe_slam";
    }
  }
  
  boss.last_action = action;
  return action;
}
8.5 Phase Transition
Phase Change Trigger:
function checkPhaseTransition(boss) {
  let hp_percent = (boss.hp_current / boss.hp_max) * 100;
  
  if (boss.phase == 1 && hp_percent <= 60) {
    triggerPhaseTransition(boss, 2);
  }
  
  if (boss.phase == 2 && hp_percent <= 30) {
    triggerPhaseTransition(boss, 3);
  }
}

function triggerPhaseTransition(boss, new_phase) {
  // Pause action queue
  pauseBattle();
  
  // Visual effects
  screenShake(0.5);
  playSound("phase_transition");
  
  // Message
  if (new_phase == 2) {
    showMessage("The symbiote armor awakens fully!");
  }
  if (new_phase == 3) {
    showMessage("The Collector's desperation takes hold!");
  }
  
  // Sprite change
  changeBossSprite(boss, "phase_" + new_phase);
  
  // Update phase
  boss.phase = new_phase;
  
  // Reset turn order (everyone acts before boss)
  resetTurnOrder();
  
  // Resume battle
  resumeBattle();
}
9. BALANCE TUNING NOTES
9.1 Expected Battle Duration
Target Turn Count:

Phase 1: 5-7 turns (party learns patterns)
Phase 2: 5-6 turns (resource management test)
Phase 3: 4-6 turns (execution challenge)
Total: 14-19 turns

Time Estimate:

~30-45 seconds per turn (player decision + animations)
Total battle: 7-14 minutes

9.2 Difficulty Checkpoints
Phase 1 - Learning Curve:

Goal: Players understand mechanics without risk of wipe
Threats: Poison damage accumulation, Collector's Grasp forces attention
Success: Party survives with >60% HP remaining

Phase 2 - Resource Check:

Goal: Test resource management (Ki, MP, Superiority Dice)
Threats: Symbiotic Rage can chunk 30-40% of squishy HP
Success: Players have resources for Phase 3 (Ninos >50 MP, Kairus >2 Ki)

Phase 3 - Execution Test:

Goal: Players execute strategy under pressure
Threats: Venom Strike can wipe party if unprepared
Success: Players survive first Venom Strike, then burn boss down

9.3 Damage Breakpoints
Boss Damage Output (Per Turn Average):

Phase 1: ~80-100 damage single target
Phase 2: ~150-180 damage (Symbiotic Rage)
Phase 3: ~120 AoE (Venom Strike) + ~100 single target

Party Damage Output (Per Turn Average):

Kairus: ~80-100 (Flurry), ~160-200 (Flurry + Fire Imbue)
Ludwig: ~50-60 (Attack), ~80-90 (Riposte procs)
Ninos: ~30-35 (Vicious Mockery), ~45-50 (Heat Metal)
Catraca: ~55-60 (Fire Bolt), ~100 (Fireball)

Party DPS: ~300-400 damage per full round (all 4 act)
Boss HP Pool: 1200
Theoretical Kill Time: 3-4 full rounds (12-16 turns)
Actual Kill Time: 14-19 turns (accounting for healing, buffs, etc.)
9.4 Healing Requirements
Boss Damage Per Phase:

Phase 1: ~500 total damage dealt (5-7 turns × ~80 avg)
Phase 2: ~700 total damage dealt (5-6 turns × ~120 avg)
Phase 3: ~600 total damage dealt (4-6 turns × ~100 avg + Venom Strike)

Party HP Pool: 1810 total (450+580+420+360)
Boss Total Damage Output: ~1800 (close to party max HP)
Healing Sources:

Ninos Healing Word: ~10 HP per cast (6 MP each)
Ninos Aura of Vitality: ~8 HP/turn × 4 turns = ~32 HP (15 MP)
Ludwig Rally: ~9 HP (1 die)
Items: Potion (50 HP)
Ninos Limit Break: 80 HP AoE + 45 HP over 3 turns

Required Healing: ~600-800 HP total (Ninos must cast 5-8 heals)
Ninos MP Pool: 110 MP
Healing Word Spam: 18 casts possible (108 MP) = ~180 HP
Balanced Approach: 4 Healing Words (24 MP) + 2 Aura of Vitality (30 MP) + Limit Break = ~180 HP (sufficient with defensive play)
9.5 Common Failure Points
Wipe Scenario 1: Phase 3 Venom Strike Unmitigated

Party ignores telegraph
Ludwig not Guarding
All take 120 damage + poison
Total damage: ~140 per character (120 + 30 poison over 3 turns)
Catraca (360 HP) and Ninos (420 HP) die immediately or next turn
Solution: Ludwig must Guard, Ninos must heal immediately after

Wipe Scenario 2: Running Out of Healing MP

Ninos spams Healing Word inefficiently
Reaches Phase 3 with <30 MP
Cannot sustain through Venom Strike + follow-up
Solution: Use Song of Rest in Phase 1, save Aura of Vitality for Phase 2+

Wipe Scenario 3: Ludwig Dies Without Second Wind

Symbiotic Rage double-hits Ludwig (if not Guarding)
Ludwig takes ~150 damage, dies before Second Wind procs (if already used)
Party loses tank, focus fire kills Catraca/Ninos
Solution: Ludwig must maintain Guard 90% of fight

Wipe Scenario 4: Ignoring Status Effects

Multiple party members Poisoned, not cleansed
Accumulates 30+ damage per round
Healing can't keep up
Solution: Ninos prioritizes Healing Word to top off poisoned targets


10. FUTURE EXPANSION HOOKS
10.1 Additional Party Members
Ostara (Wizard):

Role: Defensive utility, crowd control
Unique Command: "Arcane Ward" (shield ally, absorbs damage)
Synergy: Pairs with Catraca for double-nuke turns

Alix (Rogue):

Role: Burst DPS, evasion tank
Unique Command: "Sneak Attack" (massive crit damage if ally attacked same target)
Synergy: Benefits from Ludwig/Kairus setting up attacks

10.2 Difficulty Modes
Easy Mode:

Boss HP reduced to 900
Venom Strike damage: 80 instead of 120
Player starts with 3 Potions in inventory

Hard Mode:

Boss HP increased to 1500
Phase 2 starts at 70% HP (earlier)
Symbiotic Rage attacks 3 times instead of 2
Venom Strike deals 150 damage

10.3 Post-Battle Content
Narrative Continuation:

Marcus survives, can be questioned
Hints at bigger villain
Party can loot armory for items

Exploration:

Mine dungeon continues deeper
Random encounters with lesser enemies
Environmental puzzles

Character Progression:

Level up to 7 after battle
New abilities unlocked (future design)
Equipment found can be equipped


11. GLOSSARY
Terms & Abbreviations:

ATK: Attack stat
DEF: Defense stat
MAG: Magic stat
SPD: Speed stat
HP: Hit Points
MP: Magic Points
Ki: Kairus's resource (Monk points)
SP: Sorcery Points (Catraca's resource)
DOT: Damage Over Time
HOT: Healing Over Time
AoE: Area of Effect (hits all targets)
KO: Knocked Out (0 HP)
Proc: Activate/trigger (e.g., "passive procs")
Stack: Multiple instances of same buff/debuff

Status Effect Names:

POISON: Damage per turn
STUN: Skip next turn
CHARM: Skip next turn (mental effect)
REGEN: Heal per turn
ATK_UP: Increase attack stat
ATK_DOWN: Decrease attack stat
DEF_UP: Increase defense stat
GUARD_STANCE: Ludwig's defensive stance
FIRE_IMBUE: Kairus's fire enhancement


END OF DESIGN DOCUMENT