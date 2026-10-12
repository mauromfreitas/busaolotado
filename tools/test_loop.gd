extends SceneTree

func _init() -> void:
    change_scene_to_file("res://scenes/main.tscn")
    while current_scene == null:
        await process_frame
    var game = current_scene.get_node("GameCanvas/GameUI")
    var failures := []
    for level_id in range(1, 4):
        game.start_level(level_id)
        var taps := 0
        while game.screen == "game" and taps < 40:
            var chosen := -1
            for i in range(game.buses.size()):
                if game._path_clear(game.buses[i]):
                    chosen = i
                    break
            if chosen < 0:
                break
            game._try_send_bus(chosen)
            await create_timer(0.34).timeout
            taps += 1
        if game.screen != "result" or game.queue.size() != 0:
            failures.append(level_id)
    print("loop_first_three=" + ("ok" if failures.is_empty() else "failed:" + str(failures)))
    quit()
