extends Node2D

var GameConstants = preload("res://scripts/game_constants.gd")
var GridSystem = preload("res://scripts/grid_system.gd")
var PebbleScene = preload("res://scenes/pebble.tscn")

var grid_system: GridSystem
var current_puyo: Array = []
var next_puyo_types: Array = []
var score: int = 0
var spawn_timer: float = 0.0
var is_spawning: bool = false
var game_over: bool = false

var swipe_start_position: Vector2 = Vector2.ZERO
var is_swiping: bool = false
var swipe_side: String = ""
var rotation_accumulator: float = 0.0
var last_swipe_y: float = 0.0

func _ready():
	randomize()
	grid_system = GridSystem.new()
	grid_system.reset_grid()
	
	prepare_next_puyo()
	spawn_puyo()

func _process(delta):
	if game_over:
		return
	
	if is_spawning:
		spawn_timer -= delta
		if spawn_timer <= 0:
			spawn_puyo()
			is_spawning = false

func _input(event):
	if game_over:
		return
	
	if event is InputEventScreenTouch:
		handle_touch(event)
	elif event is InputEventScreenDrag:
		handle_drag(event)
	elif event is InputEventMouseButton:
		handle_mouse_click(event)
	elif event is InputEventKey:
		handle_keyboard(event)

func handle_touch(event: InputEventScreenTouch):
	if event.pressed:
		swipe_start_position = event.position
		is_swiping = true
		last_swipe_y = event.position.y
		swipe_side = "left" if event.position.x < get_viewport().size.x / 2 else "right"
		
		if current_puyo.size() > 0 and not is_swiping:
			var screen_width = get_viewport().size.x
			if event.position.x < screen_width / 2:
				move_puyo_left()
			else:
				move_puyo_right()
	else:
		is_swiping = false
		rotation_accumulator = 0.0

func handle_drag(event: InputEventScreenDrag):
	if not is_swiping or current_puyo.size() == 0:
		return
	
	var drag_distance = event.position - swipe_start_position
	
	if swipe_side == "left":
		var y_diff = event.position.y - last_swipe_y
		rotation_accumulator += y_diff
		
		if abs(rotation_accumulator) > 30:
			if rotation_accumulator > 0:
				rotate_puyo_cw()
			else:
				rotate_puyo_ccw()
			rotation_accumulator = 0.0
		
		last_swipe_y = event.position.y
	
	elif swipe_side == "right":
		if drag_distance.y > 50:
			drop_puyo()
			is_swiping = false

func handle_mouse_click(event: InputEventMouseButton):
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_puyo.size() > 0:
			var screen_width = get_viewport().size.x
			if event.position.x < screen_width / 2:
				move_puyo_left()
			else:
				move_puyo_right()

func handle_keyboard(event: InputEventKey):
	if not event.pressed or current_puyo.size() == 0:
		return
	
	match event.keycode:
		KEY_LEFT, KEY_A:
			move_puyo_left()
		KEY_RIGHT, KEY_D:
			move_puyo_right()
		KEY_UP, KEY_W:
			rotate_puyo_cw()
		KEY_DOWN, KEY_S:
			rotate_puyo_ccw()
		KEY_SPACE, KEY_Q:
			drop_puyo()

func spawn_puyo():
	if game_over:
		return
	
	prepare_next_puyo()
	
	var spawn_pos = $SpawnPosition.position
	var pebble1 = create_pebble(next_puyo_types[0], spawn_pos)
	var pebble2 = create_pebble(next_puyo_types[1], Vector2(spawn_pos.x, spawn_pos.y - GameConstants.CELL_SIZE))
	
	pebble1.set_puyo_partner(pebble2)
	pebble2.set_puyo_partner(pebble1)
	
	current_puyo = [pebble1, pebble2]
	
	for pebble in current_puyo:
		pebble.landed.connect(_on_pebble_landed)

func create_pebble(type: int, pos: Vector2) -> Node2D:
	var pebble = PebbleScene.instantiate()
	add_child(pebble)
	pebble.position = pos
	pebble.target_x = pos.x
	
	var sprite_name = GameConstants.PEBBLE_COLORS[type] if type < GameConstants.PEBBLE_COLORS.size() else GameConstants.WILDCARD_PEBBLE
	pebble.initialize(type, sprite_name)
	
	return pebble

func prepare_next_puyo():
	next_puyo_types.clear()
	for i in range(2):
		if randf() < 0.1:
			next_puyo_types.append(GameConstants.PebbleType.GLOWING)
		else:
			next_puyo_types.append(randi() % GameConstants.PEBBLE_COLORS.size())

func move_puyo_left():
	if can_move_puyo(Vector2(-GameConstants.CELL_SIZE, 0)):
		for pebble in current_puyo:
			pebble.move_to_x(pebble.position.x - GameConstants.CELL_SIZE)

func move_puyo_right():
	if can_move_puyo(Vector2(GameConstants.CELL_SIZE, 0)):
		for pebble in current_puyo:
			pebble.move_to_x(pebble.position.x + GameConstants.CELL_SIZE)

func can_move_puyo(offset: Vector2) -> bool:
	for pebble in current_puyo:
		var new_pos = pebble.position + offset
		var grid_pos = GameConstants.get_grid_position(new_pos)
		if not GameConstants.is_valid_grid_position(grid_pos):
			return false
		if not grid_system.is_cell_empty(grid_pos):
			return false
	return true

func rotate_puyo_cw():
	rotate_puyo(PI / 2)

func rotate_puyo_ccw():
	rotate_puyo(-PI / 2)

func rotate_puyo(angle: float):
	if current_puyo.size() != 2:
		return
	
	var pivot = current_puyo[0]
	var rotating = current_puyo[1]
	
	var old_pos = rotating.position
	rotating.rotate_around_partner(angle)
	
	var new_grid_pos = GameConstants.get_grid_position(rotating.position)
	if not GameConstants.is_valid_grid_position(new_grid_pos) or not grid_system.is_cell_empty(new_grid_pos):
		rotating.position = old_pos
		rotating.puyo_rotation -= angle

func drop_puyo():
	for pebble in current_puyo:
		pebble.drop()

func _on_pebble_landed():
	for pebble in current_puyo:
		pebble.separate_from_puyo()
		var grid_pos = GameConstants.get_grid_position(pebble.position)
		grid_system.add_pebble(grid_pos, pebble.pebble_type)
	
	current_puyo.clear()
	
	process_matches()
	
	if grid_system.is_game_over():
		game_over = true
		print("Game Over! Final Score: ", score)
	else:
		is_spawning = true
		spawn_timer = GameConstants.SPAWN_DELAY

func process_matches():
	var matches = grid_system.check_matches()
	
	if matches.size() > 0:
		var pebbles_to_remove = []
		for match_group in matches:
			for grid_pos in match_group:
				pebbles_to_remove.append(grid_pos)
		
		remove_pebbles(pebbles_to_remove)
		
		score += pebbles_to_remove.size() * GameConstants.POINTS_PER_PEBBLE
		score += matches.size() * GameConstants.POINTS_PER_CHAIN
		
		update_score_display()
		
		await get_tree().create_timer(0.3).timeout
		
		apply_gravity_to_pebbles()
		
		await get_tree().create_timer(0.5).timeout
		
		process_matches()

func remove_pebbles(positions: Array):
	for pos in positions:
		grid_system.remove_pebble(pos)
		
		for child in get_children():
			if child is Pebble:
				var child_grid_pos = GameConstants.get_grid_position(child.position)
				if child_grid_pos == pos:
					child.queue_free()

func apply_gravity_to_pebbles():
	var moved = grid_system.apply_gravity()
	
	for move_data in moved:
		for child in get_children():
			if child is Pebble:
				var child_grid_pos = GameConstants.get_grid_position(child.position)
				if child_grid_pos == move_data["from"]:
					child.position = GameConstants.get_world_position(move_data["to"])

func update_score_display():
	var score_label = $UI/ScoreLabel
	if score_label:
		score_label.text = "Score: " + str(score)

func is_cell_empty(grid_pos: Vector2i) -> bool:
	return grid_system.is_cell_empty(grid_pos)
