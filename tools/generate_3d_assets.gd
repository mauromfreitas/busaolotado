extends SceneTree

const OUT := "res://scenes/3d/"
const BLUE := Color("#4F8FE8")
const CORAL := Color("#F06B67")
const YELLOW := Color("#F3C75B")
const CREAM := Color("#F8F1DC")
const GLASS := Color("#244A67")
const DARK := Color("#24333D")
const SKIN := Color("#F5C8A2")

func mat(color: Color, roughness := 0.72, metallic := 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    m.metallic = metallic
    return m

func box(size: Vector3, color: Color, pos := Vector3.ZERO, bevel := 0.0) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    if bevel > 0.0:
        mesh.subdivide_width = 1
        mesh.subdivide_height = 1
        mesh.subdivide_depth = 1
    n.mesh = mesh
    n.material_override = mat(color)
    n.position = pos
    return n

func cyl(radius: float, height: float, color: Color, pos := Vector3.ZERO, rotation := Vector3.ZERO) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 12
    n.mesh = mesh
    n.material_override = mat(color)
    n.position = pos
    n.rotation = rotation
    return n

func capsule(radius: float, height: float, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = height
    mesh.radial_segments = 12
    mesh.rings = 4
    n.mesh = mesh
    n.material_override = mat(color)
    n.position = pos
    return n

func save_scene(root: Node, filename: String) -> void:
    for child in root.get_children():
        child.owner = root
    var packed := PackedScene.new()
    packed.pack(root)
    ResourceSaver.save(packed, OUT + filename)
    root.free()

func make_bus(length: float, width := 1.15, height := 1.45, color := CORAL, filename := "bus_small.tscn") -> void:
    var root := Node3D.new()
    root.name = "ToyBus"
    root.add_child(box(Vector3(length, width, height), color, Vector3(0, height * 0.5, 0), 0.08))
    root.add_child(box(Vector3(length * 0.88, width * 0.88, 0.18), CREAM, Vector3(0, height + 0.10, 0)))
    var window_color := mat(GLASS)
    for side in [-1.0, 1.0]:
        var windows := int(maxi(2, int(length / 0.8)))
        for i in range(windows):
            var x := -length * 0.38 + float(i) * (length * 0.76 / float(maxi(1, windows - 1)))
            var w: float = maxf(0.24, length * 0.11)
            var pane := box(Vector3(w, 0.06, height * 0.34), GLASS, Vector3(x, height * 0.72, side * (width * 0.51)))
            pane.material_override = window_color
            root.add_child(pane)
    # front windshield and bumper point toward +X.
    root.add_child(box(Vector3(0.05, height * 0.45, width * 0.76), GLASS, Vector3(length * 0.505, height * 0.72, 0)))
    root.add_child(box(Vector3(0.10, 0.18, width * 0.9), DARK, Vector3(length * 0.53, 0.23, 0)))
    for side in [-1.0, 1.0]:
        for x in [-length * 0.34, length * 0.34]:
            root.add_child(cyl(0.20, 0.14, DARK, Vector3(x, 0.27, side * (width * 0.57)), Vector3(PI * 0.5, 0, 0)))
            root.add_child(cyl(0.09, 0.15, Color("#BFC8CB"), Vector3(x, 0.27, side * (width * 0.65)), Vector3(PI * 0.5, 0, 0)))
    root.add_child(box(Vector3(0.10, 0.16, 0.16), YELLOW, Vector3(length * 0.54, height * 0.35, -width * 0.32)))
    root.add_child(box(Vector3(0.10, 0.16, 0.16), YELLOW, Vector3(length * 0.54, height * 0.35, width * 0.32)))
    save_scene(root, filename)

func make_passenger() -> void:
    var root := Node3D.new()
    root.name = "LowPolyPassenger"
    root.add_child(capsule(0.22, 0.55, CORAL, Vector3(0, 0.78, 0)))
    root.add_child(capsule(0.22, 0.42, SKIN, Vector3(0, 1.32, 0)))
    root.add_child(capsule(0.25, 0.16, DARK, Vector3(0, 1.54, 0)))
    root.add_child(cyl(0.07, 0.38, DARK, Vector3(-0.10, 0.26, 0)))
    root.add_child(cyl(0.07, 0.38, DARK, Vector3(0.10, 0.26, 0)))
    root.add_child(box(Vector3(0.12, 0.34, 0.10), DARK, Vector3(-0.10, 0.06, 0)))
    root.add_child(box(Vector3(0.12, 0.34, 0.10), DARK, Vector3(0.10, 0.06, 0)))
    root.add_child(box(Vector3(0.16, 0.45, 0.10), BLUE, Vector3(-0.27, 0.92, 0)))
    save_scene(root, "passenger_lowpoly.tscn")

func make_bay() -> void:
    var root := Node3D.new()
    root.name = "BoardingBay"
    root.add_child(box(Vector3(3.2, 0.12, 2.0), Color("#BDE4EC"), Vector3(0, 0.06, 0)))
    root.add_child(box(Vector3(3.35, 0.12, 0.12), YELLOW, Vector3(0, 0.14, -0.98)))
    root.add_child(box(Vector3(3.35, 0.12, 0.12), YELLOW, Vector3(0, 0.14, 0.98)))
    root.add_child(box(Vector3(2.5, 0.12, 0.12), Color("#D8A8E8"), Vector3(0, 0.15, 0)))
    root.add_child(box(Vector3(0.10, 1.7, 0.10), DARK, Vector3(-1.2, 0.9, -0.65)))
    root.add_child(box(Vector3(0.10, 1.7, 0.10), DARK, Vector3(1.2, 0.9, -0.65)))
    root.add_child(box(Vector3(2.7, 0.12, 1.0), Color("#63B9DE"), Vector3(0, 1.75, -0.65)))
    root.add_child(box(Vector3(1.15, 0.16, 0.38), Color("#A66C48"), Vector3(0, 0.48, 0.72)))
    save_scene(root, "boarding_bay.tscn")

func _init() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    make_bus(1.7, 1.1, 1.35, CORAL, "bus_small.tscn")
    make_bus(2.5, 1.1, 1.4, BLUE, "bus_medium.tscn")
    make_bus(3.4, 1.15, 1.45, YELLOW, "bus_long.tscn")
    make_passenger()
    make_bay()
    print("procedural_3d_assets=ok")
    quit()
