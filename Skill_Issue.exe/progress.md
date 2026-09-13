# 🎮 Skill Issue: Adaptive AI Dungeon Crawler — Progress & Architecture Report

> **Project Version:** 2.0 (Room Transitions & Adaptive Mechanics Update)  
> **Engine:** Godot 4.x (2D Top-Down Action RPG)  
> **Repository Branch:** `room_transitions`

---

## 🌟 Executive Overview

**Skill Issue** is a retro top-down dungeon crawler where an **AI Director** passively monitors and models the player's playstyle in real time (dodge direction bias, retreat habits, attack rhythm regularity, and kill tempo). The dungeon dynamically adapts the hazards in each level and prepares the **Adaptive Final Boss** with specific counter-strategies and dynamic trash-talk tailored to the player's observed flaws.

---

## 🚪 Room Transitions & Gate Mechanics

### 1. Unified Room Lifecycle Framework (`room_base.gd`)
Each room follows an automated state-machine lifecycle:
```
[Room Enter] ──> [_apply_director_modifiers()] ──> [_spawn_enemies()]
                                                          │
                                                    (Combat Phase)
                                                          │
                                                 [All Enemies Defeated]
                                                          │
                                             [_on_room_cleared() Triggered]
                                                          │
               ┌──────────────────────────────────────────┴──────────────────────────────────────────┐
               ▼                                                                                     ▼
      [Physics Blocker Removed]                                                             [3-Stage Door Animation]
  (StaticBody2D collision freed)                                                     (Closed ──> Shaking/Cracking ──> Fully Open)
               │                                                                                     │
               └──────────────────────────────────────────┬──────────────────────────────────────────┘
                                                          ▼
                                            [Exit Portal / Door Active]
                                                          │
                                              (Player Steps Into Portal)
                                                          ▼
                                        [GameManager Loads Next Level (1.5s)]
```

### 2. Multi-Layer Collision Blockers (`_door_blocker`)
- **Physics Gatekeeper:** A dedicated `StaticBody2D` with `collision_layer = 0xFFFFFFFF` (all collision layers) spawns over exit gates/grills prior to room clearance.
- **Player & Mob Blocking:** Completely prevents both the player and enemy mobs from clipping, walking over, or phasing through locked doors or floor grates before all monsters are slain.
- **Projectile Absorption:** Enemy spells, dark flasks, and spears pop against the blocker rather than passing through closed exits.
- **Clean Release:** Automatically disables and frees the collider on room clear without physics frame desync.

### 3. Dynamic 3-Stage Visual Door Transitions
Each room uses customized transition assets to represent unlocking:
| Level | Exit Style | Intact Sprite | Half-Open / Breaking | Fully Open / Broken | Transition Effect |
|---|---|---|---|---|---|
| **Room 1–2** | North Portal | *Dungeon wall arch* | — | `door_frame_open.png` | Glowing cyan/emerald portal shimmer |
| **Room 3** | Iron Gate | `door_half_open.png` | Shake + Crossfade | `room3_door_fully_open.png` | Heavy iron bars open |
| **Room 4** | Floor Abyss Grill | `room4_grill_intact.png` | `room4_grill_breaking.png` | `room4_grill_broken.png` | Metal grate cracks and shatters open |
| **Room 5** | Boss Arena | Ritual Chamber | — | Victory State | Boss defeat transition |

### 4. Phasing Archway Tunnels
- **Rooms 1–4:** Left wall (`Vector2(-540, 0)`) and Right wall (`Vector2(540, 0)`) feature archway teleporters that allow the player and regular enemies to wrap around the arena horizontally.
- **Boss Arena (Room 5) Exemption:** Archway tunnels are **cleanly disabled** (`_should_have_archway_tunnels() -> false`) in the final boss arena, and the boss entity is granted explicit immunity against phasing to maintain a tight, controlled boss duel.

---

## ⚡ New Mechanics & Combat Polish

### 1. Slippery Ice Physics (`apply_ice_effect`)
- **Friction Deceleration:** In Room 2 and dynamic Room 4 ice patches, the player's movement carries drift momentum (`ICE_FRICTION = 0.90 – 0.92`), altering dodging windows and maneuverability.

### 2. Corner Gargoyle Statue Traps & Time Punishment
- **4-Corner Placement:** Dormant stone gargoyles rest in the dungeon corners.
- **16-Second Punishment Timer:** If the player takes longer than 16 seconds to clear the room, dormant gargoyles awaken into flying melee combatants.
- **Proactive Awakening:** Attacking a stone statue awakens it immediately.

### 3. Telegraphed Attack Windups (`attack_startup_delay`)
- All melee and ranged enemies possess an adjustable `attack_startup_delay = 0.3s` window between animation start and hitbox activation, providing readable combat cues for player reaction and parry/dodge windows.

### 4. Intelligent Mob Flocking & Barrier Avoidance
- **Boids Separation:** Enemies apply soft repulsive steering vectors against adjacent allies to prevent cluster-stacking and physics-pinning the player against walls.
- **Grill / Blocker Repulsion:** Enemies in Room 4 actively repel away from the central locked grill (`door_blocker` group), preventing them from getting stuck against the closed grate.
- **Safe Spawn Clamping:** Dynamic director wave spawns in Room 4 check distance to `(0, 47)` and offset enemy spawn coordinates safely outside the central grill.

---

## 🧠 AI Director Adaptation Matrix

The global singleton `AIDirector.gd` and the child component `PlayerBehaviorTracker.gd` continuously compute the following live metrics:

| Metric Tracked | Detection Threshold | Dungeon Counter Adaptation | Boss Counter Reaction |
|---|---|---|---|
| **Aggression** | $\ge 4.0\text{ KPM}$ | **Room 3 & 4:** Spawns extra reinforcement waves. | Boss circles outside melee range and initiates heavy AoE slams. |
| **Retreating / Kiting** | $\ge 12.0\text{s}$ backing away | **Room 4:** Spawns slippery ice sheets under player. | Boss activates high-speed gap-closing lunges and projectile traps. |
| **Dodge Bias** | $\ge 4$ dashes in one direction | **Room 4:** Spawns enemies positioned to flank the biased dodge direction. | Boss pre-fires attacks cutting off predicted dash destination (`_cut_off_dodge()`). |
| **Attack Rhythm** | Interval std-dev $\le 0.18\text{s}$ | **Room 4:** Buffs enemy movement speed multipliers (`+0.4`). | Boss times counter-attacks between rhythmic swings and dodges incoming hits. |

---

## 🎮 Controls & Debug Suite

| Key / Input | Action |
|---|---|
| `W`, `A`, `S`, `D` / `Arrow Keys` | 8-Directional Top-Down Movement |
| `Left Click` / `J` / `Z` / `Space` | Melee Attack (25 DMG, directional hitbox) |
| `Right Click` / `Shift` / `C` / `K` | Dash / Dodge Roll (Invulnerability window) |
| `F1` | **Toggle Live AI Director Telemetry HUD** |
| `F2` | **[Debug] Skip to next room** |
| `F3` | **[Debug] Kill all enemies in current room** |
| `R` | **[Debug] Full run restart (resets player state & health)** |

---

## 📂 Key Source Code Architecture

- **Engine & Core Room Loop:**
  - [`scripts/room_base.gd`](file:///c:/Users/Admin/Documents/skillissue/room-branch/Skill_Issue.exe/scripts/room_base.gd) — Base class handling camera, colliders, door blocker `StaticBody2D`, animated transitions, and statue lifecycle.
  - [`scripts/game_manager.gd`](file:///c:/Users/Admin/Documents/skillissue/room-branch/Skill_Issue.exe/scripts/game_manager.gd) — Sequential level loader and transition controller.
- **Level Scripts:**
  - [`scripts/room1_tutorial.gd`](file:///c:/Users/Admin/Documents/skillissue/room-branch/Skill_Issue.exe/scripts/room1_tutorial.gd) — Controls tutorial and baseline enemies.
  - [`scripts/room2_icy.gd`](file:///c:/Users/Admin/Documents/skillissue/room-branch/Skill_Issue.exe/scripts/room2_icy.gd) — Low-friction ice arena.
  - [`scripts/room3_faster.gd`](file:///c:/Users/Admin/Documents/skillissue/room-branch/Skill_Issue.exe/scripts/room3_faster.gd) — Speed scaling with dynamic aggression checks.
  - [`scripts/room4_director.gd`](file:///c:/Users/Admin/Documents/skillissue/room-branch/Skill_Issue.exe/scripts/room4_director.gd) — Reactive director hazard triggers & abyss grill floor transition.
  - [`scripts/room5_boss.gd`](file:///c:/Users/Admin/Documents/skillissue/room-branch/Skill_Issue.exe/scripts/room5_boss.gd) — Boss arena with tunnel mechanics disabled.
- **AI & Entities:**
  - [`autoload/AIDirector.gd`](file:///c:/Users/Admin/Documents/skillissue/room-branch/autoload/AIDirector.gd) — Autoload singleton tracking player profile metrics and firing behavioral signals.
  - [`scripts/player_behavior_tracker.gd`](file:///c:/Users/Admin/Documents/skillissue/room-branch/Skill_Issue.exe/scripts/player_behavior_tracker.gd) — Retreat vector analyzer attached to Player.
  - [`scripts/player.gd`](file:///c:/Users/Admin/Documents/skillissue/room-branch/Skill_Issue.exe/scripts/player.gd) — Top-down player character controller.
  - [`scripts/zombie.gd`](file:///c:/Users/Admin/Documents/skillissue/room-branch/Skill_Issue.exe/scripts/zombie.gd) — Modular mob controller (Goblins, Skeletons, Cultists) with boids separation and blocker avoidance.
  - [`scripts/gargoyle_statue.gd`](file:///c:/Users/Admin/Documents/skillissue/room-branch/Skill_Issue.exe/scripts/gargoyle_statue.gd) — Dormant corner statue traps.
  - [`scripts/boss_enemy.gd`](file:///c:/Users/Admin/Documents/skillissue/room-branch/Skill_Issue.exe/scripts/boss_enemy.gd) — 5-phase adaptive final boss.
  - [`scripts/director_hud.gd`](file:///c:/Users/Admin/Documents/skillissue/room-branch/Skill_Issue.exe/scripts/director_hud.gd) — CanvasLayer HUD with health bar and `F1` debug telemetry.
