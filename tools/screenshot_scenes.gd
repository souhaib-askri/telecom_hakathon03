@tool
extends SceneTree

func _init():
	_run.call_deferred()

func _run():
	root.size = Vector2i(1280, 720)
	
	# Screenshot Lobby
	var sc = load("res://scenes/scrapbound/Lobby.tscn").instantiate()
	root.add_child(sc)
	for i in range(10):
		await process_frame
	var img = root.get_texture().get_image()
	if img:
		img.save_png("/home/askri/.gemini/antigravity/brain/741f7d24-72a0-4dd4-813a-7ba175006e83/lobby_current.png")
		print("Saved lobby_current.png")
	root.remove_child(sc)
	sc.queue_free()
	
	# Screenshot HUD
	var hud_sc = load("res://scenes/scrapbound/HUD.tscn").instantiate()
	root.add_child(hud_sc)
	hud_sc.custom_minimum_size = Vector2(1280, 720)
	hud_sc.size = Vector2(1280, 720)
	for i in range(10):
		await process_frame
	var img2 = root.get_texture().get_image()
	if img2:
		img2.save_png("/home/askri/.gemini/antigravity/brain/741f7d24-72a0-4dd4-813a-7ba175006e83/hud_current.png")
		print("Saved hud_current.png")
		
	quit(0)
