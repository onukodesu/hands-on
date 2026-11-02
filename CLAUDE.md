# Hands On

Open-source survival game with selectable roles. Full design brief: `docs/brief.md` — read it before any gameplay task.

## Stack
- Godot 4.7 (Standard, not .NET), GDScript only.
- Godot console binary for headless checks: `C:\Godot\Godot_v4.7.2-stable_win64_console.exe`
  (e.g. `--headless --path . --quit` to check the project loads and scripts parse).
- License: GPLv3 for code, CC BY-SA 4.0 for assets. Only add third-party assets that are CC0 or CC BY / CC BY-SA, and record the author and license in `assets/CREDITS.md`.

## Rules
- The owner (Egor) is the game designer and tester, not a programmer. Explain changes in plain Russian, short.
- Work in small steps: one task → code → tell Egor exactly what to run and what to check in-game.
- Keep content data-driven (parts, items, roles, repair tasks in data files under `data/`), so mods can add content without touching code.
- Every repair task must support three difficulty levels: novice (hints), medium, pro (full detail).
- Use static typing in GDScript. No magic numbers in gameplay code — put tunables in data or exported variables.
- Low-poly world; detailed models only for the close-up inspection mode (Tarkov-style).
- Current scope = first prototype only (see brief): mechanic role, one off-road vehicle, first-person, single player. Do not start co-op, NPCs or other roles unless asked.
- Commit after each working step with a clear message.
