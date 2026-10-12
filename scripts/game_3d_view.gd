extends Node3D

const CELL := 1.0
const BUS_SCENES := {
    2: "res://scenes/3d/bus_small.tscn",
    3: "res://scenes/3d/bus_medium.tscn",
    4: "res://scenes/3d/bus_long.tscn"
}
const COLORS := {
    "coral": Color("#F06B67"),
    "azul": Color("#4F8FE8"),
    "amarelo": Color("#F3C75B"),
    "roxo": Color("#A88BDB"),
    "verde": Color("#55BC7A"),
    "laranja": Color("#F39A54")
}

var ui: Node
var bus_nodes: Dictionary = {}
var parked_nodes: Array[Node3D] = []
var queue_nodes: Array[Node3D] = []
var camera: Camera3D
var board_root: Node3D

func _ready() -> void:
    ui = get_parent().get_node("GameCanvas/GameUI")
    _build_world()

func _mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.72
    return m

func _box(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    n.mesh = mesh
    n.material_override = _mat(color)
    n.position = pos
    return n

func _build_world() -> void:
    var env_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#DCEFF3")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#FFFFFF")
    env.ambient_light_energy = 0.65
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env_node.environment = env
    add_child(env_node)
    var sun := DirectionalLight3D.new()
    sun.light_color = Color("#FFF5D6")
    sun.light_energy = 0.9
    sun.rotation_degrees = Vector3(-55, -25, 0)
    add_child(sun)
    board_root = Node3D.new()
    board_root.name = "PuzzleBoard3D"
    add_child(board_root)
    board_root.add_child(_box(Vector3(12.5, 0.12, 15.0), Color("#86A7B4"), Vector3(0, -0.1, 0)))
    board_root.add_child(_box(Vector3(11.8, 0.08, 14.3), Color("#C9E9EE"), Vector3(0, -0.02, 0)))
    # Colorful low-poly city backdrop to give the board a toy-town identity.
    var building_colors := [Color("#F5C96A"), Color("#F18A74"), Color("#A9D9E6"), Color("#B8A6E1"), Color("#F0A77B")]
    for i in range(5):
        var bx := -5.2 + float(i) * 2.6
        var bh := 1.3 + float(i % 3) * 0.5
        board_root.add_child(_box(Vector3(2.0, bh, 0.9), building_colors[i], Vector3(bx, bh * 0.5, -7.0)))
        board_root.add_child(_box(Vector3(0.35, 0.35, 0.06), Color("#FFF0A9"), Vector3(bx - 0.45, bh * 0.65, -7.48)))
        board_root.add_child(_box(Vector3(0.35, 0.35, 0.06), Color("#FFF0A9"), Vector3(bx + 0.45, bh * 0.65, -7.48)))
    for y in range(8):
        if y % 2 == 0:
            board_root.add_child(_box(Vector3(0.7, 0.02, 0.07), Color("#FFFFFF"), Vector3(-5.2, 0.05, (float(y) - 3.5) * CELL)))
    # Sidewalk and five colored boarding bays at the far edge.
    board_root.add_child(_box(Vector3(12.5, 0.10, 1.8), Color("#F5EBDD"), Vector3(0, 0.02, -6.0)))
    for i in range(5):
        var x := -5.0 + float(i) * 2.5
        board_root.add_child(_box(Vector3(2.1, 0.10, 1.15), Color("#B7DDE7"), Vector3(x, 0.08, -5.65)))
        board_root.add_child(_box(Vector3(2.25, 0.12, 0.10), Color("#F2C94C"), Vector3(x, 0.16, -6.2)))
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 20.0
    camera.position = Vector3(0, 10.0, 18.0)
    camera.look_at_from_position(camera.position, Vector3(0, 0, 0.8), Vector3.UP)
    add_child(camera)
    camera.current = true

func _world_position(bus: Dictionary) -> Vector3:
    var grid_w: float = float(ui.grid_w)
    var grid_h: float = float(ui.grid_h)
    var x := (float(bus.get("x", 0)) + float(bus.get("size", 1)) * 0.5 - grid_w * 0.5) * CELL
    var z := (float(bus.get("y", 0)) + float(bus.get("size", 1)) * 0.5 - grid_h * 0.5) * CELL
    return Vector3(x, 0.35, z)

func _recolor(root: Node, inherited_color := "") -> void:
    var color_name: String = inherited_color if inherited_color != "" else str(root.get_meta("bus_color", ""))
    if not COLORS.has(color_name):
        return
    for child in root.get_children():
        if child is MeshInstance3D:
            var mesh_node: MeshInstance3D = child
            var source := mesh_node.material_override as StandardMaterial3D
            if source:
                var material := source.duplicate() as StandardMaterial3D
                if material.albedo_color != Color("#F8F1DC") and material.albedo_color != Color("#244A67") and material.albedo_color != Color("#24333D") and material.albedo_color != Color("#BFC8CB"):
                    material.albedo_color = COLORS[color_name]
                mesh_node.material_override = material
        _recolor(child, color_name)

func _tint_model(root: Node, color: Color) -> void:
    if root is MeshInstance3D:
        var mesh_node: MeshInstance3D = root
        var mesh := mesh_node.mesh
        if mesh:
            for surface in range(mesh.get_surface_count()):
                var source := mesh.surface_get_material(surface) as StandardMaterial3D
                if source:
                    var material := source.duplicate() as StandardMaterial3D
                    material.albedo_color = color
                    mesh_node.set_surface_override_material(surface, material)
    for child in root.get_children():
        _tint_model(child, color)

func _make_bus(bus: Dictionary) -> Node3D:
    var size := int(bus.get("size", 2))
    var scene_path: String = BUS_SCENES.get(size, BUS_SCENES[2])
    var instance: Node3D = load(scene_path).instantiate()
    instance.set_meta("bus_color", str(bus.get("color", "coral")))
    _recolor(instance)
    var horizontal := str(bus.get("dir", "right")) == "left" or str(bus.get("dir", "right")) == "right"
    instance.rotation_degrees.y = 0.0 if horizontal else 90.0
    instance.position = _world_position(bus)
    var desired_length := float(size) * CELL
    var base_length := 1.7 if size == 2 else (2.5 if size == 3 else 3.4)
    var scale_factor := desired_length / base_length
    instance.scale = Vector3(scale_factor, scale_factor, scale_factor)
    return instance

func _sync_buses() -> void:
    if not ui or ui.screen != "game":
        for node in bus_nodes.values():
            if is_instance_valid(node): node.visible = false
        return
    var seen := {}
    for bus in ui.buses:
        var id := int(bus.get("id", -1))
        seen[id] = true
        var node: Node3D
        if not bus_nodes.has(id) or not is_instance_valid(bus_nodes[id]):
            node = _make_bus(bus)
            board_root.add_child(node)
            bus_nodes[id] = node
        else:
            node = bus_nodes[id]
        node.visible = not bool(bus.get("moving", false))
        if node.visible:
            node.position = _world_position(bus)
            node.rotation_degrees.y = 0.0 if str(bus.get("dir", "right")) in ["left", "right"] else 90.0
        if float(bus.get("shake", 0.0)) > 0.0:
            node.position.x += sin(Time.get_ticks_msec() / 28.0) * 0.08
    for id in bus_nodes.keys():
        if not seen.has(id):
            bus_nodes[id].visible = false

func _sync_queue() -> void:
    if not ui or ui.screen != "game":
        for node in queue_nodes:
            node.visible = false
        return
    var shown: int = mini(8, ui.queue.size())
    while queue_nodes.size() < shown:
        var person: Node3D = load("res://scenes/3d/passenger_lowpoly.tscn").instantiate()
        person.scale = Vector3(0.65, 0.65, 0.65)
        board_root.add_child(person)
        queue_nodes.append(person)
    for i in range(queue_nodes.size()):
        var node := queue_nodes[i]
        node.visible = i < shown
        if node.visible:
            var color_name := str(ui.queue[i])
            node.position = Vector3(-4.3 + float(i) * 1.2, 0.18, -4.15)
            _tint_model(node, COLORS.get(color_name, Color("#F06B67")))

func _process(_delta: float) -> void:
    _sync_buses()
    _sync_queue()
