# SETUP GUIDE — AI Director Dungeon (Godot 4.4)

> All `.gd` scripts are already written in your project folder.  
> This guide tells you how to assemble the scenes in Godot's editor.

---

## Step 0 — Install & Open

1. Download **Godot 4.4 Stable** from [godotengine.org/download](https://godotengine.org/download/windows/)
2. Run `Godot_v4.4-stable_win64.exe`
3. Click **Import** → navigate to `C:\Users\a\Documents\Daksh\Hackbattle` → select `project.godot` → **Import & Edit**

---

## Step 1 — Register the AIDirector Autoload

The `project.godot` file already registers it, but verify:

1. Go to **Project → Project Settings → Autoload tab**
2. You should see `AIDirector` pointing to `res://autoload/AIDirector.gd`
3. If not: click the folder icon, select `autoload/AIDirector.gd`, name it `AIDirector`, click **Add**

---

## Step 2 — Create the Zombie Scene

**Scene → New Scene**

```
Zombie (CharacterBody2D)   ← root; attach scripts/zombie.gd
```

- Select the root node → Inspector → Script → `scripts/zombie.gd`
- The script auto-creates Polygon2D and CollisionShape2D at runtime
- **Save as** `scenes/enemies/Zombie.tscn`

---

## Step 3 — Create the Boss Scene

**Scene → New Scene**

```
BossEnemy (CharacterBody2D)    ← root; attach scripts/boss_enemy.gd
├── CollisionShape2D           ← RectangleShape2D, size 72x72
├── BossPolygon (Polygon2D)    ← large dark purple square (optional, script creates it if missing)
├── DialogueLabel (Label)      ← position above boss (-120, -80); large font; centered
└── HealthBar (ProgressBar)    ← anchor top-center; min=0 max=300
```

**Save as** `scenes/enemies/BossEnemy.tscn`

---

## Step 4 — Create Room Scenes (do all 5)

### Room 1 — Tutorial

**Scene → New Scene**

```
Room1_Tutorial (Node2D)          ← root; attach scripts/room1_tutorial.gd
├── PromptLabel (Label)          ← center screen, large font
├── Walls (StaticBody2D)         ← 4 CollisionShape2Ds as border walls
└── SpawnPoints (Node2D)
    ├── Point1 (Node2D)          pos: (-220, -140)
    ├── Point2 (Node2D)          pos: (220, -140)
    └── Point3 (Node2D)          pos: (0, 190)
```

**Save as** `scenes/rooms/Room1_Tutorial.tscn`

---

### Room 2 — Icy Floor

```
Room2_IcyFloor (Node2D)          ← root; attach scripts/room2_icy.gd
├── WarningLabel (Label)         ← center screen
├── IceZone (Area2D)             ← covers bottom half of room
│   └── CollisionShape2D         ← RectangleShape e.g. 800x300
├── IceVisual (Polygon2D)        ← light blue, semi-transparent over ice area
├── Walls (StaticBody2D)
└── SpawnPoints (Node2D)
    └── Point1..4 (Node2D)
```

**Save as** `scenes/rooms/Room2_IcyFloor.tscn`

> **Ice Effect in Player:** Add this to the Player script:
> ```gdscript
> func apply_ice_effect(friction: float) -> void:
>     velocity = velocity.lerp(velocity * friction, 0.3)
> ```

---

### Room 3 — Faster Enemies

```
Room3_FasterEnemies (Node2D)     ← root; attach scripts/room3_faster.gd
├── NoticeLabel (Label)          ← subtle, lower-center
├── Walls (StaticBody2D)
└── SpawnPoints (Node2D)
    └── Point1..6 (Node2D)
```

**Save as** `scenes/rooms/Room3_FasterEnemies.tscn`

---

### Room 4 — Director Room (The WOW Room)

```
Room4_Director (Node2D)          ← root; attach scripts/room4_director.gd
├── DirectorLabel (Label)        ← large center, color: soft cyan, font size 28
├── IceZone (Area2D)             ← starts hidden/disabled (script enables it)
│   └── CollisionShape2D
├── Walls (StaticBody2D)
└── SpawnPoints (Node2D)
    └── Point1..4 (Node2D)
```

**Save as** `scenes/rooms/Room4_Director.tscn`

---

### Room 5 — Boss Arena

```
Room5_Boss (Node2D)
├── BossEnemy (instance of BossEnemy.tscn)  ← pos: (0, 100)
├── Walls (StaticBody2D)
└── MusicPlayer (AudioStreamPlayer)  ← add your boss .ogg file here
```

Connect `BossEnemy.died` signal to a function that shows "YOU WIN" or loads credits.

**Save as** `scenes/rooms/Room5_Boss.tscn`

---

## Step 5 — Create the Main Scene

```
Main (Node2D)
├── RoomContainer (Node2D)       ← GameManager drops rooms here
├── Player (your existing scene)
│   └── PlayerBehaviorTracker (Node)  ← attach scripts/player_behavior_tracker.gd
├── DirectorHUD (CanvasLayer)    ← attach scripts/director_hud.gd; layer = 10
│   └── Panel (PanelContainer)  ← anchor top-right
│       └── VBox (VBoxContainer)
│           ├── Label  "[ AI Director ]"
│           ├── KillsLabel   (Label)
│           ├── DodgesLabel  (Label)
│           ├── RetreatLabel (Label)
│           └── FlagsLabel   (Label)
└── GameManager (Node)           ← attach scripts/game_manager.gd
```

Set **GameManager → room_container_path** in Inspector to `RoomContainer`.

**Set as Main Scene**: Project Settings → Application → Run → Main Scene → `scenes/Main.tscn`

---

## Step 6 — Wire the Player (two lines of code)

In the **Player script**, add these two calls:

```gdscript
# When the player attacks:
$PlayerBehaviorTracker.on_attack()

# When the player dashes (pass the movement direction vector):
$PlayerBehaviorTracker.on_dodge(input_direction)
```

That's the entire integration. The tracker handles everything else automatically.

---

## Step 7 — Add Groups

- Select your **Player node** → Node panel → Groups → add `player`
- `zombie.gd` adds itself to `enemy` group automatically
- `boss_enemy.gd` adds itself to `enemy` group automatically

---

## Step 8 — Test

Press **F5** and play.

- Kill enemies → watch Output: `[AIDirector] Kill #X`
- Dodge in same direction repeatedly → `DODGE PATTERN detected`
- Retreat from enemies → `RETREATER` flag flips
- Press **F1** in-game → Director HUD overlay toggles
- Reach Room 4 → Director messages appear on screen reacting to YOUR behavior
- Reach Room 5 → boss delivers monologue, then fights based on what it observed

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `Cannot preload Zombie.tscn` | Make sure `scenes/enemies/Zombie.tscn` exists |
| Boss doesn't speak | Ensure node is named exactly `DialogueLabel` |
| Ice has no effect | Add `apply_ice_effect(friction)` to Player script |
| Room never completes | Zombie must emit `died` signal — `zombie.gd` does this in `_die()` |
| Director HUD blank | Verify `AIDirector` autoload is registered in Project Settings |
| Boss fight never adapts | Call `$PlayerBehaviorTracker.on_attack()` in Player's attack code |
