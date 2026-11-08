#!/usr/bin/env python3
"""生成 ousic 内置关卡（.game）。运行：python3 tools/make_charts.py"""
import json, math, os, random

SONGS = [
    # id, 标题, 副标题/艺术家, bpm, bars, 主题色
    ("aurora",   "极光",     "Aurora Drift",   128, 64, "#5FD9FA"),
    ("neon",     "霓虹脉冲", "Neon Pulse",     152, 72, "#FF6BB5"),
    ("sakura",   "樱落",     "Sakura Fall",     96, 48, "#FFB6C9"),
    ("midnight", "午夜电台", "Midnight Radio", 110, 56, "#8E9BFF"),
    ("arcade",   "街机厅",   "Arcade Hall",    168, 80, "#FFD45E"),
    ("glacier",  "冰川",     "Glacier",        138, 64, "#7FE3D4"),
    ("ember",    "余烬",     "Ember",          176, 80, "#FF8A5C"),
    ("echo",     "回声",     "Echo",           124, 60, "#B78CFF"),
    ("coral",    "珊瑚海",   "Coral Sea",      144, 68, "#FF9E7A"),
    ("velocity", "极速",     "Velocity",       186, 84, "#7CFF8E"),
    ("lumen",    "流明",     "Lumen",          118, 56, "#66D9FF"),
    ("prism",    "棱镜",     "Prism",          160, 76, "#C77DFF"),
]

DIFFS = [
    # name, level offset, slots, notes per bar, double chance, hold chance
    ("Easy",   3, 8,  (3, 4),  0.00, 0.010),
    ("Normal", 7, 8,  (6, 8),  0.18, 0.020),
    ("Hard",  11, 16, (11, 14), 0.25, 0.030),
    ("Expert", 14, 16, (15, 19), 0.34, 0.040),
]

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ousic", "Resources", "Charts")


def lane_cycle(n, rng, last_lane):
    """尽量错开相邻音符的轨道，避免重复按键的枯燥感"""
    lanes = list(range(n))
    if last_lane >= 0 and n > 1:
        lanes = [l for l in lanes if l != last_lane]
        rng.shuffle(lanes)
        lanes.insert(rng.randrange(len(lanes) + 1), last_lane)
    else:
        rng.shuffle(lanes)
    return lanes


def generate(song, diff, seed):
    song_id, title, artist, bpm, bars, color = song
    name, level_offset, slots, note_range, double_chance, hold_chance = diff
    rng = random.Random(seed)
    beat = 60.0 / bpm
    bar_len = beat * 4
    start_bar, end_bar = 2, bars - 2
    notes = []
    last_time_by_lane = [-9999.0] * 4
    last_lane = -1

    level = level_offset + (seed % 3)

    for bar in range(start_bar, end_bar):
        bar_start = bar * bar_len
        # 段落感：每 8 小节强弱变化
        section = (bar - start_bar) // 8
        base = rng.randint(*note_range)
        if section % 3 == 1:
            base = int(base * 1.15)
        elif section % 3 == 2:
            base = max(note_range[0], int(base * 0.85))
        base = min(base, slots)

        chosen = sorted(rng.sample(range(slots), base))
        lanes = lane_cycle(4, rng, last_lane)

        for i, slot in enumerate(chosen):
            t_ms = round((bar_start + slot * bar_len / slots) * 1000, 1)
            lane = lanes[i % len(lanes)]
            if t_ms - last_time_by_lane[lane] < 110:
                lane = (lane + 1) % 4
                if t_ms - last_time_by_lane[lane] < 110:
                    continue
            kind = "tap"
            duration = 0.0
            if rng.random() < hold_chance and i % 3 == 0:
                kind = "hold"
                duration = round((bar_len / slots) * rng.choice([2, 3, 4]) * 1000, 1)
                if t_ms + duration > (bars - 1) * bar_len * 1000:
                    duration = 0.0
                    kind = "tap"
            notes.append({"t": t_ms, "lane": lane, "type": kind, **({"d": duration} if kind == "hold" else {})})
            last_time_by_lane[lane] = t_ms
            last_lane = lane

            # 双键（同一时刻不同轨道）
            if rng.random() < double_chance and slots - slot > 1:
                other = rng.choice([l for l in range(4) if l != lane])
                if t_ms - last_time_by_lane[other] >= 110:
                    extra = {"t": t_ms, "lane": other, "type": "tap"}
                    notes.append(extra)
                    last_time_by_lane[other] = t_ms

    # 偶尔来一个三连音收束小节
    if rng.random() < 0.5:
        t = (end_bar - 1) * bar_len
        for k in range(3):
            notes.append({"t": round((t - bar_len + k * bar_len / 3) * 1000, 1), "lane": k, "type": "tap"})

    notes.sort(key=lambda n: (n["t"], n["lane"]))

    chart = {
        "format": "ousic.game",
        "version": 1,
        "id": f"{song_id}-{name.lower()}",
        "songId": song_id,
        "title": title,
        "artist": artist,
        "charter": "OUSIC Auto Charter",
        "bpm": bpm,
        "offset": 0,
        "lanes": 4,
        "audio": {"type": "synth", "id": song_id, "bars": bars},
        "difficulty": {"name": name, "level": level},
        "color": color,
        "notes": notes,
    }
    return chart


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    total = 0
    for index, song in enumerate(SONGS):
        for diff_index, diff in enumerate(DIFFS):
            chart = generate(song, diff, seed=index * 17 + diff_index * 5 + 1)
            path = os.path.join(OUT_DIR, f"{chart['id']}.game")
            with open(path, "w", encoding="utf-8") as f:
                json.dump(chart, f, ensure_ascii=False, indent=1)
                f.write("\n")
            total += 1
            print(f"{chart['id']:<22} Lv.{chart['difficulty']['level']:<3} {len(chart['notes'])} notes")
    print(f"共 {total} 张谱面 -> {OUT_DIR}")


if __name__ == "__main__":
    main()
