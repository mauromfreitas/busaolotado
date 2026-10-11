import json
from pathlib import Path

COLORS = ["coral", "azul", "amarelo", "roxo", "verde", "laranja"]
levels = []

def bus(i, color, size, x, y, direction="right", hidden=False):
    return {"id": i + 1, "color": color, "size": size, "x": x, "y": y, "dir": direction, "hidden": hidden}

def grouped_queue(buses):
    queue = []
    for b in buses:
        queue.extend([b["color"]] * (b["size"] * 2))
    return queue

# Tutorial: intentionally clear lanes with two colors.
tutorial = [
    (1, [bus(0, "coral", 2, 0, 0), bus(1, "azul", 2, 0, 2), bus(2, "coral", 2, 3, 4), bus(3, "azul", 2, 3, 6)]),
    (2, [bus(0, "azul", 2, 2, 0), bus(1, "coral", 2, 0, 0), bus(2, "coral", 2, 0, 3), bus(3, "azul", 2, 3, 3), bus(4, "coral", 2, 0, 6)]),
    (3, [bus(0, "coral", 2, 0, 0), bus(1, "azul", 2, 3, 0), bus(2, "azul", 2, 0, 3), bus(3, "coral", 2, 3, 3), bus(4, "coral", 2, 0, 6), bus(5, "azul", 2, 3, 6)]),
]
for level_id, buses in tutorial:
    levels.append({"id": level_id, "grid": {"width": 7, "height": 8}, "buses": buses, "cones": [], "queue": grouped_queue(buses), "slots": 5, "difficulty": "tutorial"})

# Mixed-size block. Two independent lanes per row preserve a simple solution.
for level_id in range(4, 11):
    count = 8 + (level_id - 4)
    buses = []
    for i in range(count):
        row = i // 2
        lane = i % 2
        size = [2, 3, 4, 2, 3, 2, 4][i % 7]
        x = 0 if lane == 0 else 4
        if lane == 1 and size == 4:
            x = 3
        if x + size > 8:
            x = 0
            row += 1
        color = COLORS[i % (3 if level_id < 7 else 4)]
        buses.append(bus(i, color, size, x, row, "right"))
    levels.append({"id": level_id, "grid": {"width": 8, "height": 10}, "buses": buses, "cones": [], "queue": grouped_queue(buses), "slots": 5, "difficulty": "hard" if level_id == 10 else "normal"})

# Hidden-color block. The lanes remain readable; hidden buses reveal on exit.
for level_id in range(11, 21):
    count = 14 + min(6, (level_id - 11) // 2)
    buses = []
    for i in range(count):
        row = i // 2
        lane = i % 2
        size = 2 if lane == 0 else 3
        x = 0 if lane == 0 else 4
        if x + size > 8:
            x = 0
            row += 1
        color = COLORS[i % (4 if level_id < 16 else 5)]
        buses.append(bus(i, color, size, x, row, "right", hidden=(i % 2 == 1)))
    levels.append({"id": level_id, "grid": {"width": 8, "height": 10}, "buses": buses, "cones": [], "queue": grouped_queue(buses), "slots": 5, "difficulty": "hard" if level_id == 20 else "normal"})

# Cone block. Cones sit on a dedicated bottom row, never blocking the bus lanes.
for level_id in range(21, 31):
    count = min(26, 18 + (level_id - 21))
    buses = []
    positions = [(x, y) for y in range(9) for x in (0, 3, 6)]
    for i in range(count):
        x, y = positions[i]
        color = COLORS[i % (5 if level_id < 26 else 6)]
        buses.append(bus(i, color, 2, x, y, "right"))
    cones = [{"x": 1, "y": 9}, {"x": 3, "y": 9}, {"x": 5, "y": 9}]
    levels.append({"id": level_id, "grid": {"width": 8, "height": 10}, "buses": buses, "cones": cones, "queue": grouped_queue(buses), "slots": 5, "difficulty": "hard" if level_id == 30 else "normal"})

out = {"version": 1, "name": "Busão Lotado", "levels": levels}
Path("data/levels/levels.json").write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"wrote {len(levels)} levels")
