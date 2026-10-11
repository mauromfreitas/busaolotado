from pathlib import Path

p = Path('scripts/busaolotado_main.gd')
s = p.read_text()

def replace_func(src: str, name: str, new: str) -> str:
    marker = f'func {name}'
    start = src.index(marker)
    nxt = src.find('\nfunc ', start + len(marker))
    if nxt < 0:
        return src[:start] + new.rstrip() + '\n'
    return src[:start] + new.rstrip() + src[nxt:]

s = s.replace('var color_symbols := ["●", "▲", "◆", "✦", "■", "✚"]\n', '')
s = s.replace('var font: Font\n', '''var font: Font
var icon_textures: Dictionary = {}
var sfx_streams: Dictionary = {}
var motion_bus: Dictionary = {}
var motion_elapsed := 0.0
var motion_start := Vector2.ZERO
var motion_target := Vector2.ZERO
var motion_index := -1
var motion_ignore_path := false
var boarding_time := 0.0
var confetti: Array = []
''')
s = s.replace('''    font = ThemeDB.fallback_font
    get_viewport().size_changed.connect(queue_redraw)
    _load_levels()
    _load_progress()
''', '''    font = ThemeDB.fallback_font
    get_viewport().size_changed.connect(queue_redraw)
    for icon_name in ["map", "daily", "store", "settings", "account", "bay", "shuffle", "tow", "play"]:
        icon_textures[icon_name] = load("res://data/icons/%s.svg" % icon_name)
    for sound_name in ["tap", "bump", "board", "depart", "win"]:
        sfx_streams[sound_name] = load("res://data/audio/%s.wav" % sound_name)
    _load_levels()
    _load_progress()
''')

s = replace_func(s, '_process(delta: float) -> void:', '''func _process(delta: float) -> void:
    if screen == "game":
        level_elapsed += delta
    if toast_time > 0.0:
        toast_time -= delta
    if shake_time > 0.0:
        shake_time -= delta
    if boarding_time > 0.0:
        boarding_time -= delta
    if motion_elapsed > 0.0:
        motion_elapsed += delta
        if motion_elapsed >= 0.25:
            _complete_send_bus()
    if not confetti.is_empty():
        for bit in confetti:
            bit["t"] = float(bit["t"]) + delta
            bit["y"] = float(bit["y"]) + 120.0 * delta
        confetti = confetti.filter(func(bit): return float(bit["t"]) < 1.8)
    queue_redraw()

func _play_sfx(name: String) -> void:
    if not bool(progress.get("sound", true)) or not sfx_streams.has(name):
        return
    var player := AudioStreamPlayer.new()
    player.stream = sfx_streams[name]
    player.volume_db = -8.0
    add_child(player)
    player.finished.connect(player.queue_free)
    player.play()
''')

s = replace_func(s, '_draw_brand(x := 24.0, y := 44.0) -> void:', '''func _draw_brand(x := 24.0, y := 44.0) -> void:
    # Original bus mark: a compact roof, windshield and two wheels.
    draw_circle(_ui(Vector2(x + 10, y + 11)), 5.5 * _viewport_scale(), Color("#071A23"))
    draw_circle(_ui(Vector2(x + 32, y + 11)), 5.5 * _viewport_scale(), Color("#071A23"))
    _fill(_rect(x, y - 21, 42, 28), CORAL)
    _fill(_rect(x + 6, y - 28, 30, 8), SUN)
    _fill(_rect(x + 6, y - 15, 30, 11), Color("#BCEAF0"))
    _text("BUSÃO", x + 52, y + 2, 28, CREAM)
    _text("LOTADO", x + 52, y + 25, 13, SUN)

func _icon(name: String, x: float, y: float, size: float, tint := CREAM) -> void:
    var texture = icon_textures.get(name)
    if texture != null:
        draw_texture_rect(texture, _rect(x, y, size, size), false, tint)

func _draw_star(center: Vector2, radius: float, color: Color) -> void:
    var points := PackedVector2Array()
    for i in range(10):
        var r := radius if i % 2 == 0 else radius * 0.45
        var angle := -PI / 2.0 + float(i) * PI / 5.0
        points.append(_ui(center + Vector2(cos(angle), sin(angle)) * r))
    draw_colored_polygon(points, color)

func _draw_person(x: float, y: float, color: Color, scale := 1.0, bounce := 0.0) -> void:
    var yy := y - bounce
    draw_circle(_ui(Vector2(x, yy - 9 * scale)), 6.0 * scale * _viewport_scale(), Color("#FFE0B2"))
    _fill(_rect(x - 6 * scale, yy - 3 * scale, 12 * scale, 13 * scale), color)
    draw_line(_ui(Vector2(x - 4 * scale, yy + 10 * scale)), _ui(Vector2(x - 4 * scale, yy + 16 * scale)), Color("#071A23"), 2.0 * _viewport_scale())
    draw_line(_ui(Vector2(x + 4 * scale, yy + 10 * scale)), _ui(Vector2(x + 4 * scale, yy + 16 * scale)), Color("#071A23"), 2.0 * _viewport_scale())

func _draw_hand_pointer(x: float, y: float, pulse: float) -> void:
    var bob := sin(Time.get_ticks_msec() / 220.0) * 4.0
    draw_circle(_ui(Vector2(x, y + bob)), 15 * _viewport_scale(), Color(1, 0.82, 0.3, 0.16 + pulse * 0.12))
    draw_circle(_ui(Vector2(x + 1, y - 2 + bob)), 8 * _viewport_scale(), CREAM)
    draw_line(_ui(Vector2(x + 1, y - 4 + bob)), _ui(Vector2(x + 1, y - 20 + bob)), CREAM, 5 * _viewport_scale())
    draw_line(_ui(Vector2(x - 7, y + 1 + bob)), _ui(Vector2(x - 13, y + 8 + bob)), CREAM, 5 * _viewport_scale())
''')

s = replace_func(s, '_draw_home() -> void:', '''func _draw_home() -> void:
    _draw_brand(24, 64)
    _draw_coin_pill(254, 27)
    _text("PUZZLE DE TRÂNSITO • 30 FASES", 26, 128, 12, MINT)
    _text("Desembarace a rua.", 24, 182, 31, CREAM)
    _text("Faça a fila fluir.", 24, 218, 31, SUN)
    # Small street illustration instead of an instruction panel.
    _rounded_panel(24, 246, 342, 142, Color("#68757C"), Color("#A5B2B2"))
    draw_line(_ui(Vector2(24, 282)), _ui(Vector2(366, 282)), Color("#FFFFFF"), 4 * _viewport_scale())
    draw_line(_ui(Vector2(24, 348)), _ui(Vector2(366, 348)), Color("#FFFFFF"), 4 * _viewport_scale())
    for lane_x in [82.0, 176.0, 270.0]:
        draw_line(_ui(Vector2(lane_x, 304)), _ui(Vector2(lane_x + 28, 304)), Color("#F8D36D"), 3 * _viewport_scale())
    var demo_bus := {"color":"coral", "size":3, "dir":"right", "x":0, "y":0, "revealed":true}
    _draw_bus_shape(demo_bus, 52, 264, 118, 38, CORAL)
    _draw_person(256, 330, BLUE, 0.9)
    _draw_person(286, 330, YELLOW, 0.9)
    _draw_person(316, 330, PURPLE, 0.9)
    _draw_button(24, 418, 342, 64, "JOGAR", CORAL, BG)
    _icon("play", 155, 432, 30, BG)
    _icon_button(24, 494, 76, "map", "MAPA")
    _icon_button(112, 494, 76, "daily", "DIA")
    _icon_button(200, 494, 76, "store", "LOJA")
    _icon_button(288, 494, 78, "settings", "AJUSTES")
    _icon_button(24, 578, 76, "account", "ENTRAR")
    _rounded_panel(112, 578, 254, 58, Color("#0D2E3B"))
    _text("Convidado", 132, 603, 14, CREAM)
    _text("nível %02d / 30" % int(progress["unlocked"]), 132, 623, 12, MUTED)

func _icon_button(x: float, y: float, w: float, icon_name: String, label: String) -> void:
    _rounded_panel(x, y, w, 68, PANEL_2, Color("#2B6573"))
    _icon(icon_name, x + (w - 26) * 0.5, y + 8, 26, CREAM)
    _center(label, x, y + 57, w, 10, MUTED)
''')

s = replace_func(s, '_draw_map() -> void:', '''func _draw_map() -> void:
    _top_bar("MAPA DE LINHAS", true)
    _center("Escolha uma rua", 24, 101, 342, 20, CREAM)
    _center("Desbloqueie novos trajetos", 24, 124, 342, 12, MUTED)
    var start := Vector2(68, 166)
    var step_y := 57.0
    for i in range(30):
        var col := i / 10
        var row := i % 10
        var x := start.x + float(col) * 126.0 + (18.0 if row % 2 == 1 else 0.0)
        var y := start.y + float(row) * step_y
        if row < 9:
            var nx := start.x + float(col) * 126.0 + (18.0 if (row + 1) % 2 == 1 else 0.0)
            draw_line(_ui(Vector2(x, y + 17)), _ui(Vector2(nx, y + step_y - 17)), Color("#397183"), 3.0 * _viewport_scale())
        elif col < 2:
            draw_line(_ui(Vector2(x + 17, y)), _ui(Vector2(x + 126.0 - 17, y)), Color("#397183"), 3.0 * _viewport_scale())
        var level_no := i + 1
        var unlocked := level_no <= int(progress["unlocked"])
        var completed := level_no <= int(progress["completed"])
        var radius := 17.0 if level_no != current_level else 21.0
        var node_color := Color("#244F60") if not unlocked else (MINT if completed else (CORAL if level_no == current_level else PANEL_2))
        draw_circle(_ui(Vector2(x, y)), radius * _viewport_scale(), node_color)
        if level_no == current_level and unlocked:
            draw_arc(_ui(Vector2(x, y)), (radius + 5) * _viewport_scale(), 0, TAU, 32, SUN, 2.0 * _viewport_scale())
        if level_no % 10 == 0 and unlocked:
            _draw_star(Vector2(x, y), 10, SUN)
        elif unlocked:
            _center(str(level_no), x - 17, y + 5, 34, 13, BG if node_color == MINT else CREAM)
        else:
            _draw_lock(Vector2(x, y), 8, Color("#719198"))

func _draw_lock(center: Vector2, size: float, color: Color) -> void:
    _outline(_rect(center.x - size, center.y - 1, size * 2, size * 1.5), color, 2.0)
    draw_arc(_ui(center + Vector2(0, -2)), size * 0.75 * _viewport_scale(), PI, TAU, 16, color, 2 * _viewport_scale())
''')

s = replace_func(s, '_top_bar(title: String, back := false) -> void:', '''func _top_bar(title: String, back := false) -> void:
    if back:
        _draw_button(18, 18, 48, 42, "VOLTAR", PANEL_2, CREAM, Color("#2B6573"), 9)
    _text(title, 78 if back else 24, 45, 18, CREAM)
    _draw_coin_pill(254, 20)
''')

s = replace_func(s, '_draw_game() -> void:', '''func _draw_game() -> void:
    _top_bar("RUA %02d" % current_level, true)
    _text("DIFÍCIL" if _current_is_hard() else "CALMA", 24, 77, 11, SUN if _current_is_hard() else MINT)
    for i in range(slot_count):
        var x := 22.0 + float(i) * (346.0 / float(max(slot_count, 1)))
        var w := 58.0 if slot_count <= 5 else 49.0
        _draw_bay(x, 100, w, 64, i < parked.size())
        if i < parked.size():
            _draw_parked_bus(parked[i], x, 100, w, 64)
    # Sidewalk queue: people, not dots.
    _rounded_panel(22, 185, 346, 62, Color("#C9C1B4"), Color("#F4E8D6"))
    draw_line(_ui(Vector2(30, 238)), _ui(Vector2(360, 238)), Color("#A39A8D"), 2 * _viewport_scale())
    var shown: int = mini(8, queue.size())
    for i in range(shown):
        var qx := 44.0 + float(i) * 39.0
        var c := _color_for_name(str(queue[i]))
        var bounce := 0.0
        if i == 0 and boarding_time > 0.0:
            bounce = sin((0.28 - boarding_time) * 28.0) * 7.0
        _draw_person(qx, 226, c, 0.85, bounce)
    if queue.is_empty():
        _center("rua vazia", 22, 221, 346, 12, Color("#4A676C"))
    _draw_board()
    _draw_powerups()
    if current_level <= 3 and not buses.is_empty() and motion_elapsed <= 0.0:
        var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
        var target := buses[0]
        var cell := _cell_size()
        _draw_hand_pointer(22.0 + float(target["x"]) * cell + cell * 0.5, 316.0 + float(target["y"]) * cell + cell * 0.5, pulse)
    if tow_mode:
        _rounded_panel(21, 250, 348, 410, Color(0.4, 0.18, 0.12, 0.08), CORAL)
        _center("ESCOLHA UM ÔNIBUS", 21, 274, 348, 12, CORAL)
''')

s = replace_func(s, '_draw_board() -> void:', '''func _draw_board() -> void:
    var cell := _cell_size()
    var ox := 22.0
    var oy := 316.0
    # Asphalt lot with curb, lane marks and no visible logic grid.
    _rounded_panel(18, 278, 354, 372, Color("#5B666B"), Color("#B6C0BC"))
    draw_line(_ui(Vector2(24, 310)), _ui(Vector2(366, 310)), Color("#EDE9DF"), 3 * _viewport_scale())
    draw_line(_ui(Vector2(24, 645)), _ui(Vector2(366, 645)), Color("#EDE9DF"), 3 * _viewport_scale())
    for lane_y in range(grid_h):
        if lane_y % 2 == 0:
            var y := oy + float(lane_y) * cell + cell * 0.5
            draw_line(_ui(Vector2(28, y)), _ui(Vector2(48, y)), Color(1, 1, 1, 0.65), 2 * _viewport_scale())
    for cone in cones:
        var cx := ox + float(cone["x"]) * cell + cell * 0.5
        var cy := oy + float(cone["y"]) * cell + cell * 0.5
        draw_colored_polygon(PackedVector2Array([_ui(Vector2(cx, cy - cell * 0.28)), _ui(Vector2(cx - cell * 0.24, cy + cell * 0.24)), _ui(Vector2(cx + cell * 0.24, cy + cell * 0.24))]), ORANGE)
        draw_line(_ui(Vector2(cx - cell * 0.2, cy + cell * 0.12)), _ui(Vector2(cx + cell * 0.2, cy + cell * 0.12)), CREAM, 2 * _viewport_scale())
    for bus in buses:
        if not bool(bus.get("moving", false)):
            _draw_bus(bus, ox, oy, cell)
    if motion_elapsed > 0.0:
        var t := clamp((motion_elapsed - 0.0) / 0.25, 0.0, 1.0)
        var eased := 1.0 - pow(1.0 - t, 3.0)
        var pos := motion_start.lerp(motion_target, eased)
        _draw_bus_at(motion_bus, ox + pos.x * cell, oy + pos.y * cell, cell)

func _cell_size() -> float:
    return min(40.0, min(346.0 / float(max(grid_w, 1)), 330.0 / float(max(grid_h, 1))))
''')

s = replace_func(s, '_draw_bus(bus: Dictionary, ox: float, oy: float, cell: float) -> void:', '''func _draw_bus(bus: Dictionary, ox: float, oy: float, cell: float) -> void:
    var x := ox + float(bus["x"]) * cell
    var y := oy + float(bus["y"]) * cell
    var horizontal := str(bus["dir"]) == "left" or str(bus["dir"]) == "right"
    var bw := float(bus["size"]) * cell if horizontal else cell
    var bh := cell if horizontal else float(bus["size"]) * cell
    if bus.get("shake", 0.0) > 0.0:
        x += sin(Time.get_ticks_msec() / 35.0) * 3.0
    var color := _color_for_name(str(bus["color"]))
    if bool(bus.get("hidden", false)) and not bool(bus.get("revealed", false)):
        color = Color("#98A2A0")
    _draw_bus_shape(bus, x, y, bw, bh, color)

func _draw_bus_at(bus: Dictionary, x: float, y: float, cell: float) -> void:
    var horizontal := str(bus["dir"]) == "left" or str(bus["dir"]) == "right"
    var bw := float(bus["size"]) * cell if horizontal else cell
    var bh := cell if horizontal else float(bus["size"]) * cell
    _draw_bus_shape(bus, x, y, bw, bh, _color_for_name(str(bus["color"])))

func _draw_bus_shape(bus: Dictionary, x: float, y: float, bw: float, bh: float, color: Color) -> void:
    var horizontal := str(bus["dir"]) == "left" or str(bus["dir"]) == "right"
    var dir := str(bus["dir"])
    _fill(_rect(x + 3, y + bh - 1, bw - 6, 6), Color(0, 0, 0, 0.28))
    _fill(_rect(x + 2, y + 2, bw - 4, bh - 5), color)
    _fill(_rect(x + 5, y + 5, bw - 10, bh - 13), color.lightened(0.12))
    if horizontal:
        var windshield_x := x + bw - 15 if dir == "right" else x + 7
        _fill(_rect(windshield_x, y + 7, 8, bh - 17), Color("#A9DCE2"))
        var window_count := max(1, int(bw / 22.0))
        for i in range(window_count):
            var wx := x + 15.0 + float(i) * ((bw - 31.0) / float(window_count))
            _fill(_rect(wx, y + 7, 11, bh - 17), Color("#173D4B"))
        draw_circle(_ui(Vector2(x + 12, y + bh - 1)), 6 * _viewport_scale(), Color("#17252A"))
        draw_circle(_ui(Vector2(x + bw - 12, y + bh - 1)), 6 * _viewport_scale(), Color("#17252A"))
    else:
        var windshield_y := y + bh - 15 if dir == "down" else y + 7
        _fill(_rect(x + 7, windshield_y, bw - 14, 8), Color("#A9DCE2"))
        draw_circle(_ui(Vector2(x + bw - 1, y + 12)), 6 * _viewport_scale(), Color("#17252A"))
        draw_circle(_ui(Vector2(x + bw - 1, y + bh - 12)), 6 * _viewport_scale(), Color("#17252A"))
    if bool(bus.get("hidden", false)) and not bool(bus.get("revealed", false)):
        _center("?", x, y + bh * 0.64, bw, 16, Color("#24363B"))
''')

s = replace_func(s, '_draw_parked_bus(bus: Dictionary, x: float, y: float, w: float, h: float) -> void:', '''func _draw_bay(x: float, y: float, w: float, h: float, occupied: bool) -> void:
    _fill(_rect(x, y, w - 4, h - 2), Color("#6D777B"))
    draw_line(_ui(Vector2(x + 2, y + 2)), _ui(Vector2(x + w - 8, y + 2)), SUN, 3 * _viewport_scale())
    draw_line(_ui(Vector2(x + 2, y + h - 3)), _ui(Vector2(x + w - 8, y + h - 3)), SUN, 3 * _viewport_scale())
    if not occupied:
        draw_line(_ui(Vector2(x + w * 0.5, y + 15)), _ui(Vector2(x + w * 0.5, y + h - 15)), Color(1, 1, 1, 0.28), 2 * _viewport_scale())

func _draw_parked_bus(bus: Dictionary, x: float, y: float, w: float, h: float) -> void:
    var copy: Dictionary = bus.duplicate(true)
    copy["dir"] = "right"
    copy["size"] = 2
    _draw_bus_shape(copy, x + 4, y + 8, w - 12, h - 18, _color_for_name(str(bus["color"])))
    var cap := int(bus["capacity"])
    var load := int(bus["load"])
    var ratio := float(load) / float(max(cap, 1))
    _fill(_rect(x + 7, y + h - 8, (w - 14) * ratio, 3), CREAM)
''')

s = replace_func(s, '_draw_powerups() -> void:', '''func _draw_powerups() -> void:
    var p: Dictionary = progress["powers"]
    _draw_power_button(22, 744, 106, "bay", int(p.get("bay", 0)), "VAGA")
    _draw_power_button(142, 744, 106, "shuffle", int(p.get("shuffle", 0)), "ORDEM")
    _draw_power_button(262, 744, 106, "tow", int(p.get("tow", 0)), "GUINCHO")

func _draw_power_button(x: float, y: float, w: float, icon_name: String, count: int, label: String) -> void:
    _rounded_panel(x, y, w, 60, CORAL if icon_name == "tow" and tow_mode else Color("#285E68"), Color("#6EA7A5"))
    _icon(icon_name, x + 12, y + 12, 25, CREAM)
    _text(label, x + 43, y + 28, 11, CREAM)
    _center(str(count), x, y + 54, w, 10, SUN)
''')

s = replace_func(s, '_draw_result() -> void:', '''func _draw_result() -> void:
    _draw_brand(24, 58)
    _draw_coin_pill(254, 27)
    var won := last_result_coins >= 0 and queue.is_empty()
    if won:
        _draw_confetti()
    _rounded_panel(24, 153, 342, 430, Color("#173E4B"), Color("#4C8185"))
    if won:
        _center("RUA LIBERADA!", 44, 226, 302, 28, MINT)
        _center("Todo mundo embarcou.", 44, 256, 302, 14, CREAM)
        _draw_star(Vector2(195, 354), 58, SUN)
        _center("+%d moedas" % last_result_coins, 44, 466, 302, 25, SUN)
        _center("tempo %s" % _format_time(level_elapsed), 44, 494, 302, 13, MUTED)
        _draw_button(44, 520, 302, 56, "PRÓXIMA FASE", CORAL, BG)
    else:
        _center("TRÂNSITO PARADO", 44, 226, 302, 28, CORAL)
        _center("A fila precisa de outra rota.", 44, 259, 302, 14, CREAM)
        _rounded_panel(67, 320, 256, 78, Color("#0B2A36"), Color("#9D4F4B"))
        _center("CONTINUE COM UMA VAGA", 67, 350, 256, 13, SUN)
        _center("vídeo simulado de 5 segundos", 67, 374, 256, 12, MUTED)
        _draw_button(44, 430, 302, 54, "ASSISTIR VÍDEO", PANEL_2, CREAM, Color("#2B7180"), 15)
        _draw_button(44, 496, 146, 54, "TENTAR DE NOVO", CORAL, BG, Color.TRANSPARENT, 13)
        _draw_button(200, 496, 146, 54, "MAPA", PANEL_2, CREAM, Color("#2B7180"), 15)

func _draw_confetti() -> void:
    for bit in confetti:
        var c := bit["color"]
        draw_rect(Rect2(_ui(Vector2(bit["x"], bit["y"])), Vector2(5, 10) * _viewport_scale()), c, true)
''')

# Motion-aware sending replaces immediate removal with a short eased slide.
s = replace_func(s, '_send_bus(index: int, ignore_path: bool) -> void:', '''func _send_bus(index: int, ignore_path: bool) -> void:
    if parked.size() >= slot_count or motion_elapsed > 0.0:
        return
    motion_bus = buses[index].duplicate(true)
    motion_bus["revealed"] = true
    motion_bus["moving"] = true
    motion_index = index
    motion_ignore_path = ignore_path
    motion_elapsed = 0.001
    motion_start = Vector2(float(motion_bus["x"]), float(motion_bus["y"]))
    motion_target = motion_start
    var dir := str(motion_bus["dir"])
    if dir == "right": motion_target.x = float(grid_w) + 0.8
    elif dir == "left": motion_target.x = -float(motion_bus["size"]) - 0.8
    elif dir == "down": motion_target.y = float(grid_h) + 0.8
    else: motion_target.y = -float(motion_bus["size"]) - 0.8
    buses[index]["moving"] = true
    _play_sfx("tap")

func _complete_send_bus() -> void:
    if motion_index < 0 or motion_index >= buses.size():
        motion_elapsed = 0.0
        return
    var index := motion_index
    var bus: Dictionary = buses[index]
    bus["revealed"] = true
    var parked_bus := {"color": bus["color"], "size": bus["size"], "capacity": int(bus["size"]) * 2, "load": 0, "id": bus.get("id", index), "ignore_path": motion_ignore_path}
    parked.append(parked_bus)
    buses.remove_at(index)
    motion_elapsed = 0.0
    motion_index = -1
    motion_bus = {}
    _process_queue()
    _record_action("send_bus", int(parked_bus["id"]))
    _save_progress()
    if not queue.is_empty() and parked.size() >= slot_count and not _has_matching_bus(str(queue[0])):
        _finish_level(false)
    elif queue.is_empty():
        _finish_level(true)
''')

# Add feedback to blocked buses and queue boarding.
s = s.replace('''        if bool(progress["vibration"]):
            Input.vibrate_handheld(35)
        return
''', '''        if bool(progress["vibration"]):
            Input.vibrate_handheld(35)
        _play_sfx("bump")
        return
''', 1)
s = s.replace('''        queue.pop_front()
        parked[target]["load"] = int(parked[target]["load"]) + 1
''', '''        queue.pop_front()
        boarding_time = 0.28
        _play_sfx("board")
        parked[target]["load"] = int(parked[target]["load"]) + 1
''')
s = s.replace('''            if bool(progress["vibration"]):
                Input.vibrate_handheld(22)
''', '''            _play_sfx("depart")
            if bool(progress["vibration"]):
                Input.vibrate_handheld(22)
''', 1)

# Start/end result feedback and confetti.
s = s.replace('''    if won:
        var reward := 100 + (0 if used_powerups > 0 else 50)
''', '''    if won:
        _play_sfx("win")
        confetti = []
        for i in range(28):
            confetti.append({"x": 28.0 + float((i * 47) % 330), "y": 140.0 + float((i * 19) % 160), "t": 0.0, "color": color_values[i % color_values.size()]})
        var reward := 100 + (0 if used_powerups > 0 else 50)
''')

# Remove emoji/symbol fallback; visual shapes now own the icon language.
s = replace_func(s, '_symbol_for_name(name: String) -> String:', '''func _symbol_for_name(name: String) -> String:
    return ""
''')

# Game input now aligns with the asphalt lot origin and ignores taps during a slide.
s = s.replace('''func _game_tap(pos: Vector2) -> void:
    if _inside(pos, 18, 18, 48, 42):
''', '''func _game_tap(pos: Vector2) -> void:
    if motion_elapsed > 0.0:
        return
    if _inside(pos, 18, 18, 48, 42):
''')
s = s.replace('var rect := _bus_rect(bus, 22.0, 286.0, cell)', 'var rect := _bus_rect(bus, 22.0, 316.0, cell)')

p.write_text(s)
print('retheme complete')
