extends SceneTree

const OUT := "res://scenes/3d/vertical_slice_3d.tscn"
const CREAM := Color("#F8F1DC")
const SKY := Color("#DCEFF3")
const ROAD := Color("#8BA6B5")

func mat(c: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = 0.8
    return m

func box(size: Vector3, c: Color, pos: Vector3) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    n.mesh = mesh
    n.material_override = mat(c)
    n.position = pos
    return n

func add_tree(root: Node3D, pos: Vector3) -> void:
    var trunk := MeshInstance3D.new()
    var tm := CylinderMesh.new()
    tm.top_radius = 0.12
    tm.bottom_radius = 0.16
    tm.height = 1.0
    trunk.mesh = tm
    trunk.material_override = mat(Color("#8B5C3A"))
    trunk.position = pos + Vector3(0, 0.5, 0)
    root.add_child(trunk)
    var crown := MeshInstance3D.new()
    var cm := SphereMesh.new()
    cm.radius = 0.65
    cm.height = 1.3
    crown.mesh = cm
    crown.material_override = mat(Color("#59BC78"))
    crown.position = pos + Vector3(0, 1.35, 0)
    root.add_child(crown)

func adopt(root: Node, node: Node) -> void:
    node.owner = root
    for child in node.get_children():
        adopt(root, child)

func _init() -> void:
    var root := Node3D.new()
    root.name = "BusaoLotado3DVerticalSlice"
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = SKY
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#FFFFFF")
    environment.ambient_light_energy = 0.55
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.environment = environment
    root.add_child(env)
    var sun := DirectionalLight3D.new()
    sun.light_color = Color("#FFF5D6")
    sun.light_energy = 0.8
    sun.rotation_degrees = Vector3(-55, -25, 0)
    root.add_child(sun)
    root.add_child(box(Vector3(16, 0.12, 18), ROAD, Vector3(0, -0.06, 0)))
    root.add_child(box(Vector3(16.5, 0.18, 2.0), CREAM, Vector3(0, 0.03, -5.4)))
    root.add_child(box(Vector3(16.5, 0.18, 2.0), CREAM, Vector3(0, 0.03, 5.4)))
    for i in range(5):
        var bay: Node3D = load("res://scenes/3d/boarding_bay.tscn").instantiate()
        bay.position = Vector3(-5.7 + float(i) * 2.85, 0.10, -5.0)
        bay.scale = Vector3(0.72, 0.72, 0.72)
        root.add_child(bay)
    var small: Node3D = load("res://scenes/3d/bus_small.tscn").instantiate()
    small.position = Vector3(-4.7, 0.15, 0.4)
    small.rotation_degrees.y = 90
    small.scale = Vector3(0.9, 0.9, 0.9)
    root.add_child(small)
    var medium: Node3D = load("res://scenes/3d/bus_medium.tscn").instantiate()
    medium.position = Vector3(0, 0.15, 1.9)
    medium.rotation_degrees.y = 90
    root.add_child(medium)
    var long_bus: Node3D = load("res://scenes/3d/bus_long.tscn").instantiate()
    long_bus.position = Vector3(3.8, 0.15, -0.6)
    long_bus.rotation_degrees.y = 90
    long_bus.scale = Vector3(0.82, 0.82, 0.82)
    root.add_child(long_bus)
    for i in range(5):
        var person: Node3D = load("res://scenes/3d/passenger_lowpoly.tscn").instantiate()
        person.position = Vector3(-5.0 + float(i) * 0.95, 0.10, -3.25)
        person.scale = Vector3(0.7, 0.7, 0.7)
        root.add_child(person)
    for x in [-7.0, 7.0]:
        add_tree(root, Vector3(x, 0, -2.8))
        add_tree(root, Vector3(x, 0, 3.6))
    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 24.0
    camera.position = Vector3(0, 15.0, 17.0)
    camera.look_at_from_position(camera.position, Vector3(0, 0, 0), Vector3.UP)
    root.add_child(camera)
    camera.current = true
    for child in root.get_children():
        adopt(root, child)
    var packed := PackedScene.new()
    packed.pack(root)
    ResourceSaver.save(packed, OUT)
    print("vertical_slice_3d=ok")
    quit()
