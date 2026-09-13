# 🎮 Skill Issue: Context & Current Functional State

> **Repository:** [dakshshrivastava2025/SkillIssue.exe](https://github.com/dakshshrivastava2025/SkillIssue.exe)  
> **Branch:** `rooms`  
> **Engine:** Godot 4.4 Stable (2D Top-Down Action RPG)  
> **Screen Resolution:** 1280×720  

---

## 🚀 Executive Overview

**Skill Issue** is a 2D retro top-down action RPG featuring an **Adaptive AI Director**. As the player fights through a 5-room dungeon, an invisible telemetry tracker analyzes combat habits (dodge direction, retreat tendencies, attack timing, aggression levels) and dynamically modifies intermediate room environments, enemy spawns, controls, and the final adaptive boss's combat behavior and dialogue.

---

## 🛠️ Fully Functional Systems & Features Built

### 1. 🚶 Player Controller (`scripts/player.gd`)
- **8-Directional Top-Down Movement**: WASD / Arrow key movement (Speed: `210 px/s`).
- **Inverted Control Support (`invert_controls`)**: Can be activated by room environments (currently enabled during **Room 4** combat).
- **Aim & Facing Indicator**: Mouse aiming in 360° with a visible yellow facing pointer and cyan player indicator core.
- **Melee Attack**: Left-Click / `J` / `Z` swings for 25 damage with hit detection and flash feedback.
- **Dash & Dodge Roll**: `Shift` / Right-Click / `C` directional burst dash (`480 px/s`).
- **Ice Surface Drift**: Low-friction sliding physics when standing on ice zones (`apply_ice_effect`).
- **Automatic Telemetry Hookup**: Spawns and links child `PlayerBehaviorTracker` node.

---

### 2. 🧠 AI Director & Telemetry System (`autoload/ai_director.gd` & `scripts/player_behavior_tracker.gd`)
- **Real-Time Habit Tracking**:
  - **Dodge Habit Detection**: Tracks favorite dodge direction (`left`, `right`, `up`, `down`).
  - **Aggression Level**: Tracks kill speed and close-quarters engagement.
  - **Retreat Tendencies**: Detects continuous backward movement away from enemies.
  - **Attack Rhythm**: Detects predictable button-mashing attack intervals.
- **Live Telemetry HUD (`scripts/director_hud.gd`)**: Top-right overlay showing live player metrics, active flags, and Director hints.

---

### 3. 👹 Enemy Archetypes & Systems (`scripts/zombie.gd`, `scripts/gargoyle_statue.gd`, `scripts/boss_enemy.gd`)
- **5 Sprite-Animated Enemy Types**:
  - **Goblin**: Fast melee chaser.
  - **Skeleton & Armored Skeleton**: Tanky melee fighters with shields.
  - **Dark Cultist & Dark Wizard**: Ranged magic casters firing dark orb projectiles.
  - **Winged Gargoyle**: Corner statue traps that awaken when timer expires or triggered.
  - **Adaptive Final Boss (Room 5)**: Multi-phase boss that counter-picks player habits and speaks dynamic trash talk tailored to your playstyle.
- **Soft Separation Physics**: Boids-style steering prevents enemies from stacking on top of each other or trapping the player against walls.
- **Directional Animations**: 8-direction `AnimatedSprite2D` supporting walk, idle, and attack animations.

---

### 4. 🏰 5-Room Dungeon Progression Flow

| Room | Script | Key Mechanics & Functional Features |
|---|---|---|
| **Room 1: Tutorial** | `room1_tutorial.gd` | WASD movement, attack, and dash tutorial. Baseline 3 goblin spawns. Clean perimeter colliders. |
| **Room 2: Icy Floor** | `room2_icy.gd` | Center icy floor introducing low-friction sliding momentum. Mixed skeleton & goblin waves. |
| **Room 3: Faster Enemies** | `room3_faster.gd` | Octagonal iron-fence arena with 1.55× speed enemies. Spawns extra enemies if player was aggressive in Rooms 1 & 2. |
| **Room 4: The Dungeon Learns** | `room4_director.gd` | **Inverted Controls Active**. Reactive room that introduces ice when player retreats, spawns flankers in your favorite dodge direction, and speeds up enemies if your attack rhythm is predictable. |
| **Room 5: Final Boss** | `room5_boss.gd` | Colosseum arena featuring the **Adaptive Final Boss**. Adjusts boss speed, project projectiles, melee charges, and dialogue based on player profile telemetry. |

---

### 5. 🧱 Bounding Barriers & Room Collision Polish
- Custom fitted perimeter collision rects for all 5 room backgrounds (`room1_bg.png` through `room5_bg.png`).
- Octagonal outer fence collision contour in Room 3 with clean wall bounds.
- Room 4 central pit open floor layout (bounding box removed for interactive pit mechanics).
- Corner seal rects in Room 5 to prevent out-of-bounds clipping.

---

## 🎮 Quick Debug & Testing Controls

- **`F1`**: Toggle live AI Director Telemetry HUD overlay.
- **`F2`**: Advance immediately to next dungeon room.
- **`F3`**: Reset player health & stats.
- **`F4`**: Force toggle player `is_aggressive` profile flag.
- **`F5`**: Force toggle player `is_retreater` profile flag.

---

## 🎯 What Can Be Expanded / Worked On Next
1. **Dynamic Room 4 Pit Hazards**: Add trapdoor triggers or falling mechanics in the Room 4 central pit.
2. **Audio & Sound Effects**: Attach hit SFX, dash Whoosh, spell cast sounds, and room ambient tracks.
3. **Boss Special Attacks**: Add phase 3 area-of-effect spells or summon minion waves during Room 5 boss fight.
