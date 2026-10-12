extends SceneTree

func _init() -> void:
    change_scene_to_file("res://scenes/main.tscn")
    while current_scene == null:
        await process_frame
    var game = current_scene.get_node("GameCanvas/GameUI")
    game.start_level(1)
    await process_frame
    await process_frame
    var image := get_root().get_texture().get_image()
    image.save_png("user://busaolotado-game.png")
    quit()
