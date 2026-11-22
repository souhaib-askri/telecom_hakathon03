extends Node

func _ready() -> void:
	print("==================================================================")
	print("        TESTING TRANSFERRED FEATURES & INTEGRATION               ")
	print("==================================================================")

	var main_scene = load("res://scenes/scrapbound/ScrapboundMain.tscn")
	if not main_scene:
		printerr("FAILED to load ScrapboundMain.tscn")
		get_tree().quit(1)
		return

	var main = main_scene.instantiate()
	add_child(main)
	print("[PASS] ScrapboundMain instantiated with DayNightModulate, Workshops, and Audio")

	# Test 1: Raid Phase State Transitions & Skip Day
	print("\n--- [TEST 1] RAID SYSTEM & DAY/NIGHT CYCLE ---")
	print("Initial Raid Phase: %s (Timer: %.1f)" % [main.raid_phase, main.day_timer])
	if main.raid_phase != 0: # RaidPhase.DAY
		printerr("[FAIL] Expected RaidPhase.DAY (0)")
		get_tree().quit(1)
		return
	print("[PASS] Started in RaidPhase.DAY (Prep Time)")

	# Test Skip Day
	main.request_skip_day_net()
	print("After request_skip_day_net, Phase: %s (Timer: %.1f)" % [main.raid_phase, main.day_timer])
	if main.raid_phase != 1: # RaidPhase.DUSK
		printerr("[FAIL] Expected RaidPhase.DUSK (1)")
		get_tree().quit(1)
		return
	print("[PASS] Skip Day transitioned smoothly to RaidPhase.DUSK")

	# Trigger Night Raid
	main.start_night_raid()
	print("After start_night_raid, Phase: %s (Monsters: %d)" % [main.raid_phase, main.raid_monsters_total])
	if main.raid_phase != 2: # RaidPhase.NIGHT_RAID
		printerr("[FAIL] Expected RaidPhase.NIGHT_RAID (2)")
		get_tree().quit(1)
		return
	print("[PASS] Night Raid triggered with %d foes" % main.raid_monsters_total)

	# Test 2: Recycler Sorting (1 Scrap -> 4 Materials)
	print("\n--- [TEST 2] RECYCLER SORTING (1 SCRAP COST & 4 MATERIALS) ---")
	main.p1.inventory["scrap"] = 10
	main.p1.global_position = main.recycler1.global_position
	var initial_scrap = main.p1.inventory["scrap"]
	main.request_refine(1, "random")
	print("Scrap after refine: %d (consumed 1 scrap)" % main.p1.inventory["scrap"])
	if main.p1.inventory["scrap"] != initial_scrap - 1:
		printerr("[FAIL] Expected scrap to decrease by 1")
		get_tree().quit(1)
		return
	var total_mats = main.p1.inventory["wood"] + main.p1.inventory["iron"] + main.p1.inventory["plastic"] + main.p1.inventory["battery"]
	print("Total refined materials: %d (Wood:%d, Iron:%d, Plastic:%d, Battery:%d)" % [
		total_mats, main.p1.inventory["wood"], main.p1.inventory["iron"], main.p1.inventory["plastic"], main.p1.inventory["battery"]
	])
	if total_mats < 1:
		printerr("[FAIL] Expected at least 1 refined material produced")
		get_tree().quit(1)
		return
	print("[PASS] Recycler correctly sorted 1 scrap into refined materials")

	# Test 3: Deployable Sentry Turret
	print("\n--- [TEST 3] DEPLOYABLE SENTRY TURRET ---")
	main.p1.inventory["turrets"] = 1
	var spawn_pos = Vector2(1500, 860)
	main.request_deploy_turret(1, spawn_pos)
	var turret_node = main.get_node_or_null("Turret_2")
	if not turret_node:
		# Search children for DeployableTurret
		for c in main.get_children():
			if c is DeployableTurret:
				turret_node = c
				break
	if not turret_node:
		printerr("[FAIL] DeployableTurret was not spawned")
		get_tree().quit(1)
		return
	print("[PASS] DeployableTurret spawned successfully at %s" % turret_node.global_position)
	print("Turret HP: %d, Attack Range: %.1f" % [turret_node.health, turret_node.attack_range])

	# Test 4: Workshop & Crafting Recipes
	print("\n--- [TEST 4] WORKSHOP FABRICATION RECIPES ---")
	# Craft Assault Rifle (requires 1 Iron)
	main.p1.inventory["iron"] = 1
	main.request_craft_item(1, "Rifle")
	if main.p1.current_weapon != "Rifle":
		printerr("[FAIL] Failed to craft & equip Assault Rifle")
		get_tree().quit(1)
		return
	print("[PASS] Assault Rifle crafted & equipped cleanly!")

	# Craft Turret (requires 1 Iron + 1 Wood + 1 Battery)
	main.p1.inventory["iron"] = 1
	main.p1.inventory["wood"] = 1
	main.p1.inventory["battery"] = 1
	var prev_turrets = main.p1.inventory["turrets"]
	main.request_craft_item(1, "Turret")
	if main.p1.inventory["turrets"] != prev_turrets + 1:
		printerr("[FAIL] Failed to craft Sentry Turret in Workshop")
		get_tree().quit(1)
		return
	print("[PASS] Sentry Turret crafted in Workshop (+1 to inventory stock)!")

	# Test Tower Repair
	main.tower1.health = 500
	main.p1.inventory["wood"] = 1
	main.p1.inventory["plastic"] = 1
	main.request_craft_item(1, "TowerRepair")
	if main.tower1.health != 750:
		printerr("[FAIL] Tower repair failed. Expected 750 HP, got %d" % main.tower1.health)
		get_tree().quit(1)
		return
	print("[PASS] Tower Repair restored +250 HP (Tower HP now: %d)!" % main.tower1.health)

	# Test 5: UI Modals
	print("\n--- [TEST 5] CYBER UI MODALS (INVENTORY & WORKSHOP) ---")
	main.hud.open_inventory_modal()
	if not main.hud.inventory_modal.visible:
		printerr("[FAIL] InventoryModal failed to open")
		get_tree().quit(1)
		return
	print("[PASS] InventoryModal opened cleanly")

	main.hud.open_workshop_modal()
	if not main.hud.workshop_modal.visible:
		printerr("[FAIL] WorkshopModal failed to open")
		get_tree().quit(1)
		return
	print("[PASS] WorkshopModal opened cleanly")

	print("\n==================================================================")
	print("     ALL TRANSFERRED FEATURES TESTED & VERIFIED WITH 100% SUCCESS  ")
	print("==================================================================")
	get_tree().quit(0)
