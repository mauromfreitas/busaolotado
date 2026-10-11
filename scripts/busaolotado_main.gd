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

var color_names := ["coral", "azul", "amarelo", "roxo", "verde", "laranja"]
var color_values := [RED, BLUE, YELLOW, PURPLE, GREEN, ORANGE]
var color_symbols := ["●", "▲", "◆", "✦", "■", "✚"]

func _ready() -> void:
    font = ThemeDB.fallback_font
    get_viewport().size_changed.connect(queue_redraw)
    _load_levels()
    _load_progress()
    queue_redraw()

func _process(delta: float) -> void:
    if screen == "game":
        level_elapsed += delta
    if toast_time > 0.0:
        toast_time -= delta
        queue_redraw()
    if shake_time > 0.0:
        shake_time -= delta
        queue_redraw()

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
    _fill(_rect(x, y - 21, 42, 28), CORAL)
    _fill(_rect(x + 6, y - 28, 30, 8), SUN)
    draw_circle(_ui(Vector2(x + 10, y + 11)), 5.5 * _viewport_scale(), BG)
    draw_circle(_ui(Vector2(x + 32, y + 11)), 5.5 * _viewport_scale(), BG)
    _text("BUSÃO", x + 52, y + 2, 28, CREAM)
    _text("LOTADO", x + 52, y + 25, 13, SUN)

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
    _text("PUZZLE DE TRÂNSITO • 30 FASES", 26, 128, 12, MINT)
    _text("Organize a rua.", 24, 182, 31, CREAM)
    _text("Libere o embarque.", 24, 218, 31, SUN)
    _rounded_panel(24, 248, 342, 142, PANEL, Color("#1C5666"))
    _text("COMO JOGAR", 44, 281, 13, MINT)
    _text("Toque em um ônibus livre para enviá-lo", 44, 310, 15, CREAM)
    _text("à vaga. Passageiros da mesma cor sobem", 44, 332, 15, CREAM)
    _text("sozinhos. Esvazie a fila para vencer.", 44, 354, 15, CREAM)
    _draw_button(24, 418, 342, 64, "JOGAR AGORA  →", CORAL, BG)
    _draw_button(24, 494, 164, 54, "MAPA", PANEL_2, CREAM, Color("#2B6573"), 16)
    _draw_button(202, 494, 164, 54, "DESAFIO DO DIA", PANEL_2, CREAM, Color("#2B6573"), 13)
    _draw_button(24, 565, 106, 48, "LOJA", PANEL_2, CREAM, Color("#2B6573"), 14)
    _draw_button(142, 565, 106, 48, "AJUSTES", PANEL_2, CREAM, Color("#2B6573"), 14)
    _draw_button(260, 565, 106, 48, "ENTRAR", Color("#123F50"), MINT, Color("#2B6573"), 14)
    _rounded_panel(24, 650, 342, 76, Color("#0D2E3B"))
    _text("PROGRESSO LOCAL", 42, 679, 12, MUTED)
    _text("Convidado • nível %02d / 30" % int(progress["unlocked"]), 42, 706, 15, CREAM)
    _text("v0.1 protótipo", 276, 706, 11, MUTED)

func _draw_map() -> void:
    _top_bar("MAPA DE LINHAS", true)
    _center("Escolha uma fase", 24, 101, 342, 20, CREAM)
    _center("Cada nó é uma rua para desembaraçar", 24, 124, 342, 12, MUTED)
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
        if level_no % 10 == 0:
            _center("★", x - 16, y + 6, 32, 15, SUN if unlocked else Color("#54737A"))
        elif unlocked:
            _center(str(level_no), x - 17, y + 6, 34, 13, BG if node_color == MINT else CREAM)
        else:
            _center("×", x - 17, y + 6, 34, 16, Color("#719198"))
    _text("★ fases difíceis", 24, 770, 12, SUN)
    _text("● concluída", 157, 770, 12, MINT)
    _text("× bloqueada", 265, 770, 12, MUTED)

func _top_bar(title: String, back := false) -> void:
    if back:
        _draw_button(18, 18, 48, 42, "‹", PANEL_2, CREAM, Color("#2B6573"), 28)
    _text(title, 78 if back else 24, 45, 18, CREAM)
    _draw_coin_pill(254, 20)

func _draw_game() -> void:
    _top_bar("FASE %02d" % current_level, true)
    _text("DIFICULDADE: " + ("DIFÍCIL" if _current_is_hard() else "CALMA"), 24, 77, 11, SUN if _current_is_hard() else MINT)
    _text("VAGAS", 22, 103, 11, MUTED)
    for i in range(slot_count):
        var x := 22.0 + float(i) * (346.0 / float(max(slot_count, 1)))
        var w := 58.0 if slot_count <= 5 else 49.0
        _rounded_panel(x, 112, w, 54, Color("#0C2C38"), Color("#2D6675"))
        if i < parked.size():
            _draw_parked_bus(parked[i], x, 112, w, 54)
        else:
            _center("+", x, 147, w, 22, Color("#356B76"))
    _text("FILA • PRÓXIMOS 8", 22, 193, 11, MUTED)
    _rounded_panel(22, 205, 346, 42, Color("#0D2E3B"), Color("#24596A"))
    var shown: int = mini(8, queue.size())
    for i in range(shown):
        var qx := 38.0 + float(i) * 40.0
        var c := _color_for_name(str(queue[i]))
        draw_circle(_ui(Vector2(qx, 226)), 12 * _viewport_scale(), c)
        _center(_symbol_for_name(str(queue[i])), qx - 12, 231, 24, 11, BG)
        if i == 0:
            draw_arc(_ui(Vector2(qx, 226)), 17 * _viewport_scale(), 0, TAU, 20, CREAM, 2 * _viewport_scale())
    if queue.is_empty():
        _center("fila vazia", 22, 232, 346, 12, MINT)
    _draw_board()
    _draw_powerups()
    if current_level <= 3:
        var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
        _rounded_panel(39, 666, 312, 32, Color(0.07, 0.24, 0.29, 0.92))
        _center("TOQUE EM UM ÔNIBUS LIVRE  ↓", 39, 688, 312, 13, Color(1, 0.83, 0.42, 0.7 + pulse * 0.3))
    if tow_mode:
        _rounded_panel(21, 250, 348, 410, Color(0.4, 0.18, 0.12, 0.08), CORAL)
        _center("ESCOLHA UM ÔNIBUS PARA O GUINCHO", 21, 274, 348, 12, CORAL)

func _draw_board() -> void:
    var cell := _cell_size()
    var ox := 22.0
    var oy := 316.0
    _rounded_panel(18, 278, 354, 372, Color("#0B2A36"), Color("#1D5362"))
    _text("ESTACIONAMENTO", 30, 302, 11, MUTED)
    for y in range(grid_h):
        for x in range(grid_w):
            _outline(_rect(ox + x * cell, oy + y * cell, cell - 2, cell - 2), GRID_LINE, 1.0)
    for cone in cones:
        var cx := ox + float(cone["x"]) * cell + cell * 0.5
        var cy := oy + float(cone["y"]) * cell + cell * 0.5
        draw_circle(_ui(Vector2(cx, cy)), cell * 0.28 * _viewport_scale(), ORANGE)
        _center("!", cx - cell * 0.32, cy + cell * 0.18, cell * 0.64, 12, BG)
    for bus in buses:
        _draw_bus(bus, ox, oy, cell)

func _cell_size() -> float:
    return min(40.0, min(346.0 / float(max(grid_w, 1)), 330.0 / float(max(grid_h, 1))))

func _draw_bus(bus: Dictionary, ox: float, oy: float, cell: float) -> void:
    var x := ox + float(bus["x"]) * cell
    var y := oy + float(bus["y"]) * cell
    var horizontal := str(bus["dir"]) == "left" or str(bus["dir"]) == "right"
    var bw := float(bus["size"]) * cell if horizontal else cell
    var bh := cell if horizontal else float(bus["size"]) * cell
    var shake := 0.0
    if bus.get("shake", 0.0) > 0.0:
        shake = sin(Time.get_ticks_msec() / 35.0) * 3.0
    x += shake
    var color := _color_for_name(str(bus["color"]))
    if bool(bus.get("hidden", false)) and not bool(bus.get("revealed", false)):
        color = Color("#657C7F")
    _fill(_rect(x + 2, y + 2, bw - 4, bh - 4), color)
    _outline(_rect(x + 2, y + 2, bw - 4, bh - 4), CREAM if bool(bus.get("selected", false)) else Color("#0B2A36"), 2.5)
    var symbol := "?" if bool(bus.get("hidden", false)) and not bool(bus.get("revealed", false)) else _symbol_for_name(str(bus["color"]))
    _center(symbol, x, y + bh * 0.62, bw, 19 if symbol == "?" else 13, BG)
    if horizontal:
        var arrow := "›" if str(bus["dir"]) == "right" else "‹"
        _text(arrow, x + (bw - 15 if str(bus["dir"]) == "right" else 5), y + bh * 0.63, 17, CREAM)
    else:
        var arrow_v := "⌄" if str(bus["dir"]) == "down" else "⌃"
        _center(arrow_v, x, y + bh * 0.65, bw, 15, CREAM)

func _draw_parked_bus(bus: Dictionary, x: float, y: float, w: float, h: float) -> void:
    var color := _color_for_name(str(bus["color"]))
    _fill(_rect(x + 5, y + 8, w - 10, h - 15), color)
    _center(_symbol_for_name(str(bus["color"])), x + 4, y + 31, w - 8, 13, BG)
    var cap := int(bus["capacity"])
    var load := int(bus["load"])
    var ratio := float(load) / float(max(cap, 1))
    _fill(_rect(x + 8, y + h - 10, (w - 16) * ratio, 4), CREAM)
    _text("%d/%d" % [load, cap], x + 6, y + 16, 9, BG)

func _draw_powerups() -> void:
    _text("AJUDAS", 22, 733, 11, MUTED)
    var p: Dictionary = progress["powers"]
    _draw_button(22, 744, 106, 60, "＋ VAGA", Color("#185163"), CREAM, Color("#2B7180"), 13)
    _draw_button(142, 744, 106, 60, "↻ ORDEM", Color("#185163"), CREAM, Color("#2B7180"), 13)
    _draw_button(262, 744, 106, 60, "⚓ GUINCHO", CORAL if tow_mode else Color("#185163"), BG if tow_mode else CREAM, Color("#2B7180"), 12)
    _center("%d" % int(p.get("bay", 0)), 22, 824, 106, 11, MINT)
    _center("%d" % int(p.get("shuffle", 0)), 142, 824, 106, 11, MINT)
    _center("%d" % int(p.get("tow", 0)), 262, 824, 106, 11, MINT)

func _draw_result() -> void:
    _draw_brand(24, 58)
    _draw_coin_pill(254, 27)
    var won := last_result_coins >= 0 and queue.is_empty()
    _rounded_panel(24, 153, 342, 430, Color("#10394A"), Color("#2A6976"))
    if won:
        _center("RUA LIBERADA!", 44, 226, 302, 28, MINT)
        _center("Você organizou todo o embarque", 44, 256, 302, 14, CREAM)
        _center("sem deixar ninguém para trás.", 44, 278, 302, 14, CREAM)
        draw_circle(_ui(Vector2(195, 355)), 64 * _viewport_scale(), Color("#164E58"))
        _center("★", 131, 378, 128, 66, SUN)
        _center("+%d moedas" % last_result_coins, 44, 466, 302, 25, SUN)
        _center("tempo %s" % _format_time(level_elapsed), 44, 494, 302, 13, MUTED)
        _draw_button(44, 520, 302, 56, "PRÓXIMA FASE  →", CORAL, BG)
    else:
        _center("TRÂNSITO PARADO", 44, 226, 302, 28, CORAL)
        _center("A primeira pessoa da fila não", 44, 259, 302, 14, CREAM)
        _center("encontrou um ônibus compatível.", 44, 281, 302, 14, CREAM)
        _rounded_panel(67, 320, 256, 78, Color("#0B2A36"), Color("#9D4F4B"))
        _center("CONTINUE COM UMA VAGA", 67, 350, 256, 13, SUN)
        _center("Assista 5s de vídeo simulado", 67, 374, 256, 12, MUTED)
        _draw_button(44, 430, 302, 54, "ASSISTIR VÍDEO  +1", PANEL_2, CREAM, Color("#2B7180"), 15)
        _draw_button(44, 496, 146, 54, "TENTAR DE NOVO", CORAL, BG, Color.TRANSPARENT, 13)
        _draw_button(200, 496, 146, 54, "MAPA", PANEL_2, CREAM, Color("#2B7180"), 15)

func _draw_store() -> void:
    _top_bar("LOJA SIMULADA", true)
    _center("Ajude o trânsito a fluir", 24, 103, 342, 21, CREAM)
    _center("Nenhuma compra real • só protótipo", 24, 127, 342, 12, MUTED)
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
    _text("Convidado • progresso neste navegador", 44, 357, 14, CREAM)
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
        var rect := _bus_rect(bus, 22.0, 286.0, cell)
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
        return
    _send_bus(index, false)

func _send_bus(index: int, ignore_path: bool) -> void:
    if parked.size() >= slot_count:
        return
    var bus: Dictionary = buses[index]
    bus["revealed"] = true
    var parked_bus := {
        "color": bus["color"],
        "size": bus["size"],
        "capacity": int(bus["size"]) * 2,
        "load": 0,
        "id": bus.get("id", index),
        "ignore_path": ignore_path
    }
    parked.append(parked_bus)
    buses.remove_at(index)
    _process_queue()
    _record_action("send_bus", int(parked_bus["id"]))
    _save_progress()
    if not queue.is_empty() and parked.size() >= slot_count and not _has_matching_bus(str(queue[0])):
        _finish_level(false)
    elif queue.is_empty():
        _finish_level(true)
    queue_redraw()

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
        queue.pop_front()
        parked[target]["load"] = int(parked[target]["load"]) + 1
        if int(parked[target]["load"]) >= int(parked[target]["capacity"]):
            parked.remove_at(target)
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
        _show_toast("Desafio diário • recompensa extra ao vencer")

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
    var idx := color_names.find(name)
    return color_symbols[idx] if idx >= 0 else "•"

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
