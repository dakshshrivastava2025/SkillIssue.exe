# SkillIssue.exe — The Gaslighting AI Boss

A 2D psychological boss fight game built in **Godot 4.3** where the boss adapts to player habits in real-time, reverses game rules, inverts controls, distorts UI, and delivers dynamic gaslighting commentary.

---

## 🎮 Controls

* **Movement**: `A` / `D` or `Left` / `Right` Arrow Keys
* **Jump**: `Space` or `W` / `Up` Arrow
* **Dash**: `Shift` or `K`
* **Attack**: `J` or `Left Mouse Button`

---

## 🧠 Core Features & Mechanics

### 1. Real-Time Telemetry & Habit Tracker (`telemetry_tracker.gd`)
* Tracks jump streaks, consecutive attack whiffs, roll/dodge directions, and low-HP panic states.
* Feeds continuous data snapshots to both the Rule Alteration Engine and LLM Dialogue Generator.

### 2. Psychological Rule Alterations (`gaslight_manager.gd`)
* **Jump Spam Punisher**: Suppresses jump physics or introduces low-ceiling gravity shock.
* **Dodge Bias Inversion**: Inverts horizontal control mapping when player predictably rolls in one direction.
* **Health Bar Gaslight**: Distorts and scrambles the HP bar when the player is panicked.
* **Fake OS Popups**: Displays simulated Windows-style fatal errors to break the 4th wall.

### 3. AI Dialogue & Commentary (`llm_connector.gd`)
* Dynamic contextual sarcasm generated based on active telemetry.
* Ready for Google Gemini API key or seamless offline mock fallback.

### 4. Custom Visual FX (`screen_glitch.gdshader`)
* Screen-space chromatic aberration and glitch tear effects during psychological boss phases.
