extends SceneTree

func _init() -> void:
    change_scene_to_file("res://scenes/3d/vertical_slice_3d.tscn")
    while current_scene == null:
        await process_frame
    await process_frame
    await process_frame
    var image := get_root().get_texture().get_image()
    image.save_png("user://busaolotado-3d-slice.png")
    quit()
