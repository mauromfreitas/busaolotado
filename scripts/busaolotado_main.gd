extends Node2D

const BASE_SIZE := Vector2(390, 844)
const SAVE_PATH := "user://busaolotado_save.json"
const LEVEL_PATH := "res://data/levels/levels.json"

const BG := Color("#081F2B")
const PANEL := Color("#10394A")
const PANEL_2 := Color("#15495A")
const CREAM := Color("#FFF8E7")
const MUTED := Color("#A9C4C9")
const CORAL := Color("#FF715B")
const SUN := Color("#FFD166")
const MINT := Color("#58D6B1")
const RED := Color("#F26B5B")
const BLUE := Color("#48A9D9")
const YELLOW := Color("#F3C969")
const PURPLE := Color("#A88BDB")
const GREEN := Color("#69C28B")
const ORANGE := Color("#F49B59")
const GRID_LINE := Color("#24596A")

var screen := "home"
var level_db: Array = []
var current_level := 1
var progress := {
    "unlocked": 1,
    "completed": 0,
    "coins": 500,
    "powers": {"bay": 1, "shuffle": 1, "tow": 1},
    "sound": true,
    "vibration": true,
    "daily_claimed": "",
    "metrics": []
}
var buses: Array = []
var parked: Array = []
var cones: Array = []
var queue: Array = []
var grid_w := 7
var grid_h := 8
var slot_count := 5
var extra_bay_used := false
var tow_mode := false
var game_started_at := 0
var used_powerups := 0
var level_elapsed := 0.0
var toast := ""
var toast_time := 0.0
var shake_time := 0.0
var last_result_coins := 0
var daily_mode := false
var debug_taps := 0
var font: Font
var icon_textures: Dictionary = {}
var sfx_streams: Dictionary = {}
var motion_bus: Dictionary = {}
var motion_elapsed := 0.0
var motion_start := Vector2.ZERO
var motion_target := Vector2.ZERO
var motion_index := -1
var motion_ignore_path := false
var boarding_time := 0.0
var boarding_visuals: Array = []
var confetti: Array = []

var color_names := ["coral", "azul", "amarelo", "roxo", "verde", "laranja"]
var color_values := [RED, BLUE, YELLOW, PURPLE, GREEN, ORANGE]

func _ready() -> void:
    font = ThemeDB.fallback_font
    get_viewport().size_changed.connect(queue_redraw)
    for icon_name in ["map", "daily", "store", "settings", "account", "bay", "shuffle", "tow", "play"]:
        icon_textures[icon_name] = load("res://data/icons/%s.svg" % icon_name)
    for sound_name in ["tap", "bump", "board", "depart", "win"]:
        sfx_streams[sound_name] = load("res://data/audio/%s.wav" % sound_name)
    _load_levels()
    _load_progress()
    queue_redraw()

func _process(delta: float) -> void:
    if screen == "game":
        level_elapsed += delta
    if toast_time > 0.0:
        toast_time -= delta
    if shake_time > 0.0:
        shake_time -= delta
    if boarding_time > 0.0:
        boarding_time -= delta
    if not boarding_visuals.is_empty():
        for passenger in boarding_visuals:
            passenger["t"] = float(passenger["t"]) + delta / 0.34
        boarding_visuals = boarding_visuals.filter(func(passenger): return float(passenger["t"]) < 1.0)
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
    if DisplayServer.get_name() == "headless" or not bool(progress.get("sound", true)) or not sfx_streams.has(name):
        return
    var player := AudioStreamPlayer.new()
    player.stream = sfx_streams[name]
    player.volume_db = -8.0
    add_child(player)
    player.finished.connect(player.queue_free)
    player.play()
func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        _handle_tap(_to_logical(event.position))
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _handle_tap(_to_logical(event.position))

func _load_levels() -> void:
    if not FileAccess.file_exists(LEVEL_PATH):
        return
    var file := FileAccess.open(LEVEL_PATH, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY and parsed.has("levels"):
        level_db = parsed["levels"]

func _load_progress() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        _save_progress()
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    var saved = JSON.parse_string(file.get_as_text())
    if typeof(saved) == TYPE_DICTIONARY:
        for key in saved.keys():
            progress[key] = saved[key]
        if not progress.has("powers") or typeof(progress["powers"]) != TYPE_DICTIONARY:
            progress["powers"] = {"bay": 1, "shuffle": 1, "tow": 1}

func _save_progress() -> void:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(progress))

func _viewport_scale() -> float:
    var size := get_viewport_rect().size
    return min(size.x / BASE_SIZE.x, size.y / BASE_SIZE.y)

func _offset() -> Vector2:
    var s := _viewport_scale()
    var size := get_viewport_rect().size
    var remaining: Vector2 = size - BASE_SIZE * s
    return remaining / 2.0

func _ui(v: Vector2) -> Vector2:
    return _offset() + v * _viewport_scale()

func _rect(x: float, y: float, w: float, h: float) -> Rect2:
    return Rect2(_ui(Vector2(x, y)), Vector2(w, h) * _viewport_scale())

func _to_logical(pos: Vector2) -> Vector2:
    return (pos - _offset()) / _viewport_scale()

func _fill(rect: Rect2, color: Color) -> void:
    draw_rect(rect, color, true)

func _outline(rect: Rect2, color: Color, width := 2.0) -> void:
    draw_rect(rect, color, false, max(1.0, width * _viewport_scale()))

func _text(value: String, x: float, y: float, size := 16, color := CREAM, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
    draw_string(font, _ui(Vector2(x, y)), value, align, width * _viewport_scale() if width > 0 else -1, int(size * _viewport_scale()), color)

func _center(value: String, x: float, y: float, width: float, size := 16, color := CREAM) -> void:
    _text(value, x, y, size, color, width, HORIZONTAL_ALIGNMENT_CENTER)

func _rounded_panel(x: float, y: float, w: float, h: float, color := PANEL, border := Color.TRANSPARENT) -> void:
    _fill(_rect(x, y, w, h), color)
    if border.a > 0.0:
        _outline(_rect(x, y, w, h), border, 2.0)

func _draw() -> void:
    _fill(Rect2(Vector2.ZERO, get_viewport_rect().size), BG)
    if screen == "home":
        _draw_home()
    elif screen == "map":
        _draw_map()
    elif screen == "game":
        _draw_game()
    elif screen == "result":
        _draw_result()
    elif screen == "store":
        _draw_store()
    elif screen == "settings":
        _draw_settings()
    elif screen == "debug":
        _draw_debug()
    if toast_time > 0.0:
        _rounded_panel(30, 755, 330, 48, Color("#0A2C39"), CORAL)
        _center(toast, 30, 785, 330, 14, CREAM)

func _draw_brand(x := 24.0, y := 44.0) -> void:
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
    var s := scale * _viewport_scale()
    # Soft contact shadow gives the tiny character a grounded, 2.5D silhouette.
    _draw_ellipse_poly(_ui(Vector2(x, yy + 17 * scale)), Vector2(11, 3) * s, Color(0, 0, 0, 0.22))
    # Legs, shoes and a rounded torso with a shaded side.
    draw_line(_ui(Vector2(x - 3 * scale, yy + 9 * scale)), _ui(Vector2(x - 5 * scale, yy + 17 * scale)), Color("#26323A"), 3.0 * s)
    draw_line(_ui(Vector2(x + 3 * scale, yy + 9 * scale)), _ui(Vector2(x + 5 * scale, yy + 17 * scale)), Color("#26323A"), 3.0 * s)
    _fill(_rect(x - 7 * scale, yy - 3 * scale, 14 * scale, 14 * scale), color.darkened(0.18))
    _fill(_rect(x - 5 * scale, yy - 4 * scale, 8 * scale, 12 * scale), color.lightened(0.15))
    # Arms angled away from the body read better while the passenger is moving.
    draw_line(_ui(Vector2(x - 6 * scale, yy)), _ui(Vector2(x - 11 * scale, yy + 7 * scale)), color.darkened(0.25), 2.5 * s)
    draw_line(_ui(Vector2(x + 6 * scale, yy)), _ui(Vector2(x + 11 * scale, yy + 7 * scale)), color.darkened(0.25), 2.5 * s)
    # Head, hair cap, face highlight and tiny nose.
    draw_circle(_ui(Vector2(x, yy - 10 * scale)), 7.0 * s, Color("#F6C99E"))
    draw_circle(_ui(Vector2(x, yy - 13 * scale)), 7.0 * s, Color("#4A3030"))
    draw_arc(_ui(Vector2(x, yy - 10 * scale)), 6.0 * s, 0.15, PI - 0.15, 12, Color("#F6C99E"), 3.0 * s)
    draw_circle(_ui(Vector2(x + 3 * scale, yy - 10 * scale)), 0.9 * s, Color("#24343A"))

func _draw_ellipse_poly(center: Vector2, radii: Vector2, color: Color) -> void:
    var points := PackedVector2Array()
    for i in range(20):
        var a := TAU * float(i) / 20.0
        points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
    draw_colored_polygon(points, color)

func _draw_boarding_visuals() -> void:
    for passenger in boarding_visuals:
        var t: float = clamp(float(passenger["t"]), 0.0, 1.0)
        var eased: float = 1.0 - pow(1.0 - t, 3.0)
        var from_pos: Vector2 = passenger["from"]
        var to_pos: Vector2 = passenger["to"]
        var pos := from_pos.lerp(to_pos, eased)
        pos.y -= sin(t * PI) * 48.0
        var shadow_pos := from_pos.lerp(to_pos, eased)
        _draw_ellipse_poly(_ui(shadow_pos + Vector2(0, 14)), Vector2(10 - 4 * t, 3) * _viewport_scale(), Color(0, 0, 0, 0.18))
        _draw_person(pos.x, pos.y, passenger["color"], 0.68, 0.0)

func _draw_hand_pointer(x: float, y: float, pulse: float) -> void:
    var bob := sin(Time.get_ticks_msec() / 220.0) * 4.0
    draw_circle(_ui(Vector2(x, y + bob)), 15 * _viewport_scale(), Color(1, 0.82, 0.3, 0.16 + pulse * 0.12))
    draw_circle(_ui(Vector2(x + 1, y - 2 + bob)), 8 * _viewport_scale(), CREAM)
    draw_line(_ui(Vector2(x + 1, y - 4 + bob)), _ui(Vector2(x + 1, y - 20 + bob)), CREAM, 5 * _viewport_scale())
    draw_line(_ui(Vector2(x - 7, y + 1 + bob)), _ui(Vector2(x - 13, y + 8 + bob)), CREAM, 5 * _viewport_scale())
func _draw_coin_pill(x: float, y: float) -> void:
    _rounded_panel(x, y, 112, 38, PANEL_2, Color("#2B6573"))
    draw_circle(_ui(Vector2(x + 20, y + 19)), 9 * _viewport_scale(), SUN)
    _center("$", x + 11, y + 25, 18, 13, BG)
    _text(str(int(progress["coins"])), x + 36, y + 25, 16, CREAM)

func _draw_button(x: float, y: float, w: float, h: float, label: String, fill := CORAL, color := BG, outline := Color.TRANSPARENT, size := 17) -> void:
    _rounded_panel(x, y, w, h, fill, outline)
    _center(label, x, y + h * 0.62, w, size, color)

func _draw_home() -> void:
    _draw_brand(24, 64)
    _draw_coin_pill(254, 27)
    _text("PUZZLE DE TRÂNSITO | 30 FASES", 26, 128, 12, MINT)
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
    _icon("play", 316, 435, 24, BG)
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
func _draw_map() -> void:
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
func _top_bar(title: String, back := false) -> void:
    if back:
        _draw_button(18, 18, 48, 42, "VOLTAR", PANEL_2, CREAM, Color("#2B6573"), 9)
    _text(title, 78 if back else 24, 45, 18, CREAM)
    _draw_coin_pill(254, 20)
func _draw_game() -> void:
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
    _draw_boarding_visuals()
    if current_level <= 3 and not buses.is_empty() and motion_elapsed <= 0.0:
        var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
        var target: Dictionary = buses[0]
        var cell := _cell_size()
        _draw_hand_pointer(22.0 + float(target["x"]) * cell + cell * 0.5, 316.0 + float(target["y"]) * cell + cell * 0.5, pulse)
    if tow_mode:
        _rounded_panel(21, 250, 348, 410, Color(0.4, 0.18, 0.12, 0.08), CORAL)
        _center("ESCOLHA UM ÔNIBUS", 21, 274, 348, 12, CORAL)
func _draw_board() -> void:
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
        var t: float = clamp((motion_elapsed - 0.0) / 0.25, 0.0, 1.0)
        var eased: float = 1.0 - pow(1.0 - t, 3.0)
        var pos: Vector2 = motion_start.lerp(motion_target, eased)
        _draw_bus_at(motion_bus, ox + pos.x * cell, oy + pos.y * cell, cell)

func _cell_size() -> float:
    return min(40.0, min(346.0 / float(max(grid_w, 1)), 330.0 / float(max(grid_h, 1))))

func _draw_bus(bus: Dictionary, ox: float, oy: float, cell: float) -> void:
    var x := ox + float(bus["x"]) * cell
    var y := oy + float(bus["y"]) * cell
    var horizontal := str(bus["dir"]) == "left" or str(bus["dir"]) == "right"
    var bw := float(bus["size"]) * cell if horizontal else cell
    var bh := cell if horizontal else float(bus["size"]) * cell
    if bus.get("shake", 0.0) > 0.0:
        x += sin(Time.get_ticks_msec() / 35.0) * 3.0
    var color: Color = _color_for_name(str(bus["color"]))
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
    # Layered vector planes create a small toy-like 3D bus without a heavy 3D renderer.
    _draw_ellipse_poly(_ui(Vector2(x + bw * 0.5, y + bh + 3)), Vector2(max(8.0, bw * 0.42), 4.0) * _viewport_scale(), Color(0, 0, 0, 0.28))
    _fill(_rect(x + 2, y + 5, bw - 4, bh - 6), color.darkened(0.28))
    _fill(_rect(x + 2, y + 2, bw - 4, bh - 8), color)
    draw_colored_polygon(PackedVector2Array([_ui(Vector2(x + 6, y + 3)), _ui(Vector2(x + bw - 6, y + 3)), _ui(Vector2(x + bw - 11, y + 9)), _ui(Vector2(x + 11, y + 9))]), color.lightened(0.26))
    _fill(_rect(x + 5, y + 9, bw - 10, bh - 18), color.darkened(0.05))
    if horizontal:
        var windshield_x: float = x + bw - 15 if dir == "right" else x + 7
        _fill(_rect(windshield_x, y + 10, 8, bh - 20), Color("#C4F0F0"))
        var window_count: int = maxi(1, int(bw / 22.0))
        for i in range(window_count):
            var wx := x + 15.0 + float(i) * ((bw - 31.0) / float(window_count))
            _fill(_rect(wx, y + 10, 11, bh - 20), Color("#173D4B"))
            draw_line(_ui(Vector2(wx + 2, y + 11)), _ui(Vector2(wx + 8, y + 11)), Color(0.72, 0.95, 0.96, 0.6), 1.5 * _viewport_scale())
        draw_circle(_ui(Vector2(x + 12, y + bh - 1)), 6 * _viewport_scale(), Color("#17252A"))
        draw_circle(_ui(Vector2(x + bw - 12, y + bh - 1)), 6 * _viewport_scale(), Color("#17252A"))
        draw_circle(_ui(Vector2(x + 12, y + bh - 1)), 2.4 * _viewport_scale(), Color("#B9C1BC"))
        draw_circle(_ui(Vector2(x + bw - 12, y + bh - 1)), 2.4 * _viewport_scale(), Color("#B9C1BC"))
        var front_x: float = x + bw - 5 if dir == "right" else x + 5
        draw_circle(_ui(Vector2(front_x, y + 12)), 2.0 * _viewport_scale(), SUN)
        draw_circle(_ui(Vector2(front_x, y + bh - 12)), 2.0 * _viewport_scale(), SUN)
    else:
        var windshield_y: float = y + bh - 15 if dir == "down" else y + 7
        _fill(_rect(x + 7, windshield_y, bw - 14, 8), Color("#C4F0F0"))
        draw_circle(_ui(Vector2(x + bw - 1, y + 12)), 6 * _viewport_scale(), Color("#17252A"))
        draw_circle(_ui(Vector2(x + bw - 1, y + bh - 12)), 6 * _viewport_scale(), Color("#17252A"))
        draw_circle(_ui(Vector2(x + bw - 1, y + 12)), 2.4 * _viewport_scale(), Color("#B9C1BC"))
        draw_circle(_ui(Vector2(x + bw - 1, y + bh - 12)), 2.4 * _viewport_scale(), Color("#B9C1BC"))
        var front_y: float = y + bh - 5 if dir == "down" else y + 5
        draw_circle(_ui(Vector2(x + 12, front_y)), 2.0 * _viewport_scale(), SUN)
        draw_circle(_ui(Vector2(x + bw - 12, front_y)), 2.0 * _viewport_scale(), SUN)
    if bool(bus.get("hidden", false)) and not bool(bus.get("revealed", false)):
        _center("?", x, y + bh * 0.64, bw, 16, Color("#24363B"))
func _draw_bay(x: float, y: float, w: float, h: float, occupied: bool) -> void:
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
func _draw_powerups() -> void:
    var p: Dictionary = progress["powers"]
    _draw_power_button(22, 744, 106, "bay", int(p.get("bay", 0)), "VAGA")
    _draw_power_button(142, 744, 106, "shuffle", int(p.get("shuffle", 0)), "ORDEM")
    _draw_power_button(262, 744, 106, "tow", int(p.get("tow", 0)), "GUINCHO")

func _draw_power_button(x: float, y: float, w: float, icon_name: String, count: int, label: String) -> void:
    _rounded_panel(x, y, w, 60, CORAL if icon_name == "tow" and tow_mode else Color("#285E68"), Color("#6EA7A5"))
    _icon(icon_name, x + 12, y + 12, 25, CREAM)
    _text(label, x + 43, y + 28, 11, CREAM)
    _center(str(count), x, y + 54, w, 10, SUN)
func _draw_result() -> void:
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
        var c: Color = bit["color"]
        draw_rect(Rect2(_ui(Vector2(bit["x"], bit["y"])), Vector2(5, 10) * _viewport_scale()), c, true)
func _draw_store() -> void:
    _top_bar("LOJA SIMULADA", true)
    _center("Ajude o trânsito a fluir", 24, 103, 342, 21, CREAM)
    _center("Nenhuma compra real | só protótipo", 24, 127, 342, 12, MUTED)
    _rounded_panel(24, 153, 342, 80, Color("#163F4D"), Color("#2B7180"))
    _text("SALDO ATUAL", 44, 185, 12, MUTED)
    _text("%d moedas" % int(progress["coins"]), 44, 214, 24, SUN)
    var packs := [["PACOTE RUA", "1.000 moedas", "R$ 3,90"], ["PACOTE AVENIDA", "3.000 moedas", "R$ 9,90"], ["PACOTE TERMINAL", "8.000 moedas", "R$ 19,90"]]
    for i in range(3):
        var y := 258.0 + float(i) * 105.0
        _rounded_panel(24, y, 342, 86, PANEL, Color("#24596A"))
        _text(packs[i][0], 44, y + 28, 14, CREAM)
        _text(packs[i][1], 44, y + 55, 14, SUN)
        _draw_button(252, y + 19, 92, 48, packs[i][2], CORAL, BG, Color.TRANSPARENT, 14)
    _rounded_panel(24, 590, 342, 92, Color("#0D2E3B"), Color("#2B7180"))
    _text("MÉTRICA DE INTENÇÃO", 44, 621, 12, MINT)
    _text("Cada clique nos pacotes é registrado localmente", 44, 648, 12, MUTED)
    _text("para validar o interesse, sem cobrança.", 44, 668, 12, MUTED)

func _draw_settings() -> void:
    _top_bar("AJUSTES", true)
    _center("Seu jogo, suas regras", 24, 103, 342, 21, CREAM)
    _rounded_panel(24, 145, 342, 64, PANEL, Color("#2B7180"))
    _text("Som", 44, 182, 16, CREAM)
    _draw_button(270, 157, 76, 40, "LIGADO" if progress["sound"] else "OFF", MINT if progress["sound"] else Color("#34545B"), BG if progress["sound"] else MUTED, Color.TRANSPARENT, 12)
    _rounded_panel(24, 221, 342, 64, PANEL, Color("#2B7180"))
    _text("Vibração", 44, 258, 16, CREAM)
    _draw_button(270, 233, 76, 40, "LIGADA" if progress["vibration"] else "OFF", MINT if progress["vibration"] else Color("#34545B"), BG if progress["vibration"] else MUTED, Color.TRANSPARENT, 11)
    _rounded_panel(24, 297, 342, 92, Color("#163F4D"), Color("#2B7180"))
    _text("CONTA", 44, 328, 12, MUTED)
    _text("Convidado | progresso neste navegador", 44, 357, 14, CREAM)
    _draw_button(244, 315, 102, 46, "ENTRAR", PANEL_2, MINT, Color("#2B7180"), 13)
    _draw_button(24, 417, 342, 52, "POLÍTICA DE PRIVACIDADE", PANEL_2, CREAM, Color("#2B7180"), 14)
    _draw_button(24, 481, 342, 52, "FERRAMENTAS DE DEBUG", PANEL_2, CREAM, Color("#2B7180"), 14)
    _draw_button(24, 560, 342, 52, "REINICIAR PROGRESSO", Color("#5E3540"), Color("#FFD7CE"), Color("#A44F59"), 14)
    _text("Login opcional: Google e e-mail preparados", 24, 665, 12, MUTED)
    _text("Apple fica desativado até configurar credenciais.", 24, 686, 12, MUTED)

func _draw_debug() -> void:
    _top_bar("DEBUG / EDITOR", true)
    _center("Validador local", 24, 102, 342, 21, CREAM)
    var valid := _validate_levels()
    _rounded_panel(24, 132, 342, 102, Color("#10394A"), Color("#2B7180"))
    _text("30 níveis carregados", 44, 164, 15, CREAM)
    _text("BFS/DFS estrutural: " + ("OK" if valid else "REVISAR"), 44, 193, 15, MINT if valid else CORAL)
    _text("JSON ajustável sem alterar o código", 44, 216, 12, MUTED)
    _draw_button(24, 258, 164, 52, "EXPORTAR CSV", PANEL_2, CREAM, Color("#2B7180"), 13)
    _draw_button(202, 258, 164, 52, "EXPORTAR JSON", PANEL_2, CREAM, Color("#2B7180"), 13)
    _rounded_panel(24, 337, 342, 215, Color("#0D2E3B"), Color("#24596A"))
    _text("MÉTRICAS LOCAIS", 44, 370, 12, MINT)
    _text("Ações salvas: %d" % int(progress["metrics"].size()), 44, 405, 15, CREAM)
    _text("Nível desbloqueado: %02d" % int(progress["unlocked"]), 44, 432, 15, CREAM)
    _text("Nível concluído: %02d" % int(progress["completed"]), 44, 459, 15, CREAM)
    _text("Saldo: %d moedas" % int(progress["coins"]), 44, 486, 15, CREAM)
    _text("Editor completo disponível nesta tela", 44, 525, 12, MUTED)
    _draw_button(24, 584, 342, 52, "VOLTAR AO JOGO", CORAL, BG, Color.TRANSPARENT, 15)

func _handle_tap(pos: Vector2) -> void:
    if screen == "home":
        _home_tap(pos)
    elif screen == "map":
        _map_tap(pos)
    elif screen == "game":
        _game_tap(pos)
    elif screen == "result":
        _result_tap(pos)
    elif screen == "store":
        _store_tap(pos)
    elif screen == "settings":
        _settings_tap(pos)
    elif screen == "debug":
        _debug_tap(pos)

func _home_tap(pos: Vector2) -> void:
    if _inside(pos, 24, 418, 342, 64):
        start_level(int(progress["unlocked"]))
    elif _inside(pos, 24, 494, 164, 54):
        screen = "map"
    elif _inside(pos, 202, 494, 164, 54):
        _start_daily()
    elif _inside(pos, 24, 565, 106, 48):
        screen = "store"
    elif _inside(pos, 142, 565, 106, 48):
        screen = "settings"
    elif _inside(pos, 260, 565, 106, 48):
        _show_toast("Login opcional: progresso convidado preservado")
    elif _inside(pos, 24, 650, 342, 76):
        debug_taps += 1
        if debug_taps >= 5:
            screen = "debug"
            debug_taps = 0
    queue_redraw()

func _map_tap(pos: Vector2) -> void:
    if _inside(pos, 18, 18, 48, 42):
        screen = "home"
        queue_redraw()
        return
    var start := Vector2(68, 166)
    for i in range(30):
        var col := i / 10
        var row := i % 10
        var x := start.x + float(col) * 126.0 + (18.0 if row % 2 == 1 else 0.0)
        var y := start.y + float(row) * 57.0
        if pos.distance_to(Vector2(x, y)) < 27 and i + 1 <= int(progress["unlocked"]):
            start_level(i + 1)
            return

func _game_tap(pos: Vector2) -> void:
    if motion_elapsed > 0.0:
        return
    if _inside(pos, 18, 18, 48, 42):
        _save_progress()
        screen = "map"
        queue_redraw()
        return
    if _inside(pos, 22, 744, 106, 60):
        _use_extra_bay()
        return
    if _inside(pos, 142, 744, 106, 60):
        _use_shuffle()
        return
    if _inside(pos, 262, 744, 106, 60):
        _arm_tow()
        return
    var cell := _cell_size()
    for i in range(buses.size() - 1, -1, -1):
        var bus: Dictionary = buses[i]
        var rect := _bus_rect(bus, 22.0, 316.0, cell)
        if rect.has_point(pos):
            if tow_mode:
                _tow_bus(i)
            else:
                _try_send_bus(i)
            return

func _result_tap(pos: Vector2) -> void:
    var won := queue.is_empty()
    if won and _inside(pos, 44, 520, 302, 56):
        var next: int = mini(30, current_level + 1)
        start_level(next)
    elif not won and _inside(pos, 44, 430, 302, 54):
        _watch_video()
    elif not won and _inside(pos, 44, 496, 146, 54):
        start_level(current_level)
    elif _inside(pos, 200, 496, 146, 54) or _inside(pos, 44, 584, 302, 52):
        screen = "map"
    queue_redraw()

func _store_tap(pos: Vector2) -> void:
    if _inside(pos, 18, 18, 48, 42):
        screen = "home"
        queue_redraw()
        return
    for i in range(3):
        var y := 258.0 + float(i) * 105.0
        if _inside(pos, 252, y + 19, 92, 48):
            var amounts := [1000, 3000, 8000]
            progress["coins"] = int(progress["coins"]) + amounts[i]
            progress["metrics"].append({"event":"store_intent", "pack":i + 1, "timestamp":Time.get_datetime_string_from_system()})
            _save_progress()
            _show_toast("+%d moedas creditadas (simulado)" % amounts[i])
            queue_redraw()
            return

func _settings_tap(pos: Vector2) -> void:
    if _inside(pos, 18, 18, 48, 42):
        screen = "home"
    elif _inside(pos, 270, 157, 76, 40):
        progress["sound"] = not bool(progress["sound"])
        _save_progress()
    elif _inside(pos, 270, 233, 76, 40):
        progress["vibration"] = not bool(progress["vibration"])
        _save_progress()
    elif _inside(pos, 24, 481, 342, 52):
        screen = "debug"
    elif _inside(pos, 24, 560, 342, 52):
        progress = {"unlocked":1,"completed":0,"coins":500,"powers":{"bay":1,"shuffle":1,"tow":1},"sound":true,"vibration":true,"daily_claimed":"","metrics":[]}
        _save_progress()
        _show_toast("Progresso reiniciado")
    queue_redraw()

func _debug_tap(pos: Vector2) -> void:
    if _inside(pos, 18, 18, 48, 42) or _inside(pos, 24, 584, 342, 52):
        screen = "settings"
    elif _inside(pos, 24, 258, 164, 52):
        _export_csv()
    elif _inside(pos, 202, 258, 164, 52):
        _export_json()
    queue_redraw()

func _inside(pos: Vector2, x: float, y: float, w: float, h: float) -> bool:
    return Rect2(x, y, w, h).has_point(pos)

func start_level(id: int) -> void:
    if id < 1 or id > level_db.size():
        id = 1
    current_level = id
    var data: Dictionary = level_db[id - 1]
    grid_w = int(data["grid"]["width"])
    grid_h = int(data["grid"]["height"])
    slot_count = int(data.get("slots", 5))
    extra_bay_used = false
    tow_mode = false
    used_powerups = 0
    level_elapsed = 0.0
    boarding_visuals = []
    parked = []
    cones = Array(data.get("cones", [])).duplicate(true)
    queue = Array(data["queue"]).duplicate(true)
    buses = []
    for raw in data["buses"]:
        var bus: Dictionary = raw.duplicate(true)
        bus["revealed"] = not bool(bus.get("hidden", false))
        bus["shake"] = 0.0
        bus["selected"] = false
        buses.append(bus)
    screen = "game"
    progress["metrics"].append({"event":"level_start", "level":id, "timestamp":Time.get_datetime_string_from_system()})
    _save_progress()
    queue_redraw()

func _try_send_bus(index: int) -> void:
    if parked.size() >= slot_count:
        _show_toast("Todas as vagas estão ocupadas")
        return
    var bus: Dictionary = buses[index]
    if not _path_clear(bus):
        bus["shake"] = 0.45
        shake_time = 0.45
        _show_toast("Ops! Esse ônibus está bloqueado")
        if bool(progress["vibration"]):
            Input.vibrate_handheld(35)
        _play_sfx("bump")
        return
    _send_bus(index, false)

func _send_bus(index: int, ignore_path: bool) -> void:
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
func _path_clear(bus: Dictionary) -> bool:
    var bx := int(bus["x"])
    var by := int(bus["y"])
    var size := int(bus["size"])
    var dir := str(bus["dir"])
    var occupied := {}
    for other in buses:
        if other == bus:
            continue
        var cells := _bus_cells(other)
        for cell in cells:
            occupied["%d:%d" % [cell.x, cell.y]] = true
    var cx := bx
    var cy := by
    if dir == "right":
        cx += size
        while cx < grid_w:
            if occupied.has("%d:%d" % [cx, cy]) or _cone_at(cx, cy):
                return false
            cx += 1
    elif dir == "left":
        cx -= 1
        while cx >= 0:
            if occupied.has("%d:%d" % [cx, cy]) or _cone_at(cx, cy):
                return false
            cx -= 1
    elif dir == "down":
        cy += size
        while cy < grid_h:
            if occupied.has("%d:%d" % [cx, cy]) or _cone_at(cx, cy):
                return false
            cy += 1
    else:
        cy -= 1
        while cy >= 0:
            if occupied.has("%d:%d" % [cx, cy]) or _cone_at(cx, cy):
                return false
            cy -= 1
    return true

func _bus_cells(bus: Dictionary) -> Array:
    var result: Array = []
    var horizontal := str(bus["dir"]) == "left" or str(bus["dir"]) == "right"
    for i in range(int(bus["size"])):
        result.append(Vector2i(int(bus["x"]) + (i if horizontal else 0), int(bus["y"]) + (0 if horizontal else i)))
    return result

func _cone_at(x: int, y: int) -> bool:
    for cone in cones:
        if int(cone["x"]) == x and int(cone["y"]) == y:
            return true
    return false

func _bus_rect(bus: Dictionary, ox: float, oy: float, cell: float) -> Rect2:
    var horizontal := str(bus["dir"]) == "left" or str(bus["dir"]) == "right"
    var bw := float(bus["size"]) * cell if horizontal else cell
    var bh := cell if horizontal else float(bus["size"]) * cell
    return Rect2(ox + float(bus["x"]) * cell, oy + float(bus["y"]) * cell, bw, bh)

func _process_queue() -> void:
    var safety := 0
    while not queue.is_empty() and safety < 200:
        safety += 1
        var front := str(queue[0])
        var target := -1
        for i in range(parked.size()):
            if str(parked[i]["color"]) == front and int(parked[i]["load"]) < int(parked[i]["capacity"]):
                target = i
                break
        if target < 0:
            break
        var bay_x: float = 22.0 + float(target) * (346.0 / float(max(slot_count, 1)))
        var bay_w: float = 58.0 if slot_count <= 5 else 49.0
        var passenger_color: Color = _color_for_name(front)
        boarding_visuals.append({"from": Vector2(44, 226), "to": Vector2(bay_x + bay_w * 0.5, 132), "color": passenger_color, "t": 0.0})
        queue.pop_front()
        boarding_time = 0.28
        _play_sfx("board")
        parked[target]["load"] = int(parked[target]["load"]) + 1
        if int(parked[target]["load"]) >= int(parked[target]["capacity"]):
            parked.remove_at(target)
            _play_sfx("depart")
            if bool(progress["vibration"]):
                Input.vibrate_handheld(22)

func _has_matching_bus(color: String) -> bool:
    for bus in parked:
        if str(bus["color"]) == color and int(bus["load"]) < int(bus["capacity"]):
            return true
    for bus in buses:
        if str(bus["color"]) == color:
            return true
    return false

func _arm_tow() -> void:
    if int(progress["powers"].get("tow", 0)) <= 0:
        _show_toast("Você não tem guinchos")
        return
    tow_mode = not tow_mode
    _show_toast("Toque em um ônibus para rebocar" if tow_mode else "Guincho cancelado")
    queue_redraw()

func _tow_bus(index: int) -> void:
    if parked.size() >= slot_count:
        _show_toast("Libere uma vaga antes de usar o guincho")
        return
    progress["powers"]["tow"] = int(progress["powers"]["tow"]) - 1
    used_powerups += 1
    tow_mode = false
    _send_bus(index, true)
    _show_toast("Guincho usado: bloqueio ignorado")

func _use_extra_bay() -> void:
    if extra_bay_used:
        _show_toast("A vaga extra já está ativa")
    elif int(progress["powers"].get("bay", 0)) <= 0 and int(progress["coins"]) < 300:
        _show_toast("Vaga extra custa 300 moedas")
    else:
        if int(progress["powers"].get("bay", 0)) > 0:
            progress["powers"]["bay"] = int(progress["powers"]["bay"]) - 1
        else:
            progress["coins"] = int(progress["coins"]) - 300
        slot_count += 1
        extra_bay_used = true
        used_powerups += 1
        _record_action("extra_bay", current_level)
        _save_progress()
        _show_toast("Vaga extra aberta")
    queue_redraw()

func _use_shuffle() -> void:
    if int(progress["powers"].get("shuffle", 0)) <= 0 and int(progress["coins"]) < 200:
        _show_toast("Embaralhar custa 200 moedas")
        return
    if int(progress["powers"].get("shuffle", 0)) > 0:
        progress["powers"]["shuffle"] = int(progress["powers"]["shuffle"]) - 1
    else:
        progress["coins"] = int(progress["coins"]) - 200
    buses.shuffle()
    used_powerups += 1
    _record_action("shuffle", current_level)
    _save_progress()
    _show_toast("Ordem dos ônibus reorganizada")
    queue_redraw()

func _watch_video() -> void:
    slot_count += 1
    extra_bay_used = true
    screen = "game"
    _show_toast("Vídeo simulado concluído: +1 vaga")
    queue_redraw()

func _finish_level(won: bool) -> void:
    if won:
        _play_sfx("win")
        confetti = []
        for i in range(28):
            confetti.append({"x": 28.0 + float((i * 47) % 330), "y": 140.0 + float((i * 19) % 160), "t": 0.0, "color": color_values[i % color_values.size()]})
        var reward := 100 + (0 if used_powerups > 0 else 50)
        if _current_is_hard():
            reward *= 2
        last_result_coins = reward
        progress["coins"] = int(progress["coins"]) + reward
        progress["completed"] = max(int(progress["completed"]), current_level)
        progress["unlocked"] = min(30, max(int(progress["unlocked"]), current_level + 1))
    else:
        last_result_coins = -1
    progress["metrics"].append({"event":"level_end", "level":current_level, "won":won, "seconds":level_elapsed, "powerups":used_powerups, "timestamp":Time.get_datetime_string_from_system()})
    _save_progress()
    screen = "result"
    queue_redraw()

func _current_is_hard() -> bool:
    return current_level == 10 or current_level == 20 or current_level == 30

func _format_time(value: float) -> String:
    var total := int(value)
    return "%02d:%02d" % [total / 60, total % 60]

func _start_daily() -> void:
    var today := Time.get_date_string_from_system()
    if str(progress.get("daily_claimed", "")) == today:
        _show_toast("Desafio de hoje já concluído")
    else:
        daily_mode = true
        start_level(3 + (abs(today.hash()) % 10))
        _show_toast("Desafio diário | recompensa extra ao vencer")

func _record_action(action: String, value) -> void:
    progress["metrics"].append({"event":action, "value":value, "timestamp":Time.get_datetime_string_from_system()})

func _show_toast(message: String) -> void:
    toast = message
    toast_time = 2.3
    queue_redraw()

func _color_for_name(name: String) -> Color:
    var idx := color_names.find(name)
    return color_values[idx] if idx >= 0 else CREAM

func _symbol_for_name(name: String) -> String:
    return ""
func _validate_levels() -> bool:
    if level_db.size() != 30:
        return false
    for level in level_db:
        var totals := {}
        for bus in level["buses"]:
            var c := str(bus["color"])
            totals[c] = int(totals.get(c, 0)) + int(bus["size"]) * 2
        var queued := {}
        for c in level["queue"]:
            queued[str(c)] = int(queued.get(str(c), 0)) + 1
        for c in totals.keys():
            if int(totals[c]) != int(queued.get(c, 0)):
                return false
        if level.get("slots", 5) != 5:
            return false
    return true

func _export_csv() -> void:
    var lines := ["event,level,value,seconds,powerups,timestamp"]
    for row in progress["metrics"]:
        lines.append("%s,%s,%s,%s,%s,%s" % [row.get("event", ""), row.get("level", ""), row.get("value", ""), row.get("seconds", ""), row.get("powerups", ""), row.get("timestamp", "")])
    var file := FileAccess.open("user://busaolotado_metrics.csv", FileAccess.WRITE)
    file.store_string("\n".join(lines))
    _show_toast("CSV exportado no armazenamento local")

func _export_json() -> void:
    var file := FileAccess.open("user://busaolotado_level_editor.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(level_db[current_level - 1] if not level_db.is_empty() else {}))
    _show_toast("JSON da fase atual exportado")
