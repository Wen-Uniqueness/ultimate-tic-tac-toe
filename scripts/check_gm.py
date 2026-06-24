# encoding: utf-8
with open("scripts/game_manager.gd", encoding="utf-8") as f:
    lines = f.readlines()
print(f"Total lines: {len(lines)}")
for i, line in enumerate(lines):
    if "_on_undo_pressed" in line or "sync_from_data" in line or "reset_visuals" in line or "_sync_all" in line:
        print(f"{i+1}: {line.rstrip()}")
