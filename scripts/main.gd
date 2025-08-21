# Main.gd - Game orchestrator that manages the overall game flow
#
# Purpose: Coordinates between Puyo, GameField, and UI components.
#          Handles input, spawning, scoring, and game state management.
#
# Functions/Methods:
# - _ready(): Initializes game components
# - _draw(): Renders debug grid if enabled
# - _process(delta): Main game loop update
# - _input(event): Routes input events to handlers
# - handle_touch(event): Processes touch input
# - handle_drag(event): Processes swipe gestures
# - handle_mouse_click(event): Processes mouse clicks
# - handle_keyboard(event): Processes keyboard input
# - spawn_puyo(): Creates a new puyo pair
# - create_pebble(type, pos): Creates individual pebble
# - prepare_next_puyo(): Generates next puyo types
# - move_puyo_left(): Sends left movement to current puyo
# - move_puyo_right(): Sends right movement to current puyo
# - rotate_puyo_cw(): Sends clockwise rotation to puyo
# - rotate_puyo_ccw(): Sends counter-clockwise rotation to puyo
# - drop_puyo(): Sends drop command to current puyo
# - _on_puyo_landed(puyo): Handles puyo landing event
# - _on_puyo_discarded(positions, types): Converts puyo to field elements
# - process_chain_reaction(): Handles matching and gravity cycles
# - _on_matches_found(count, pebbles): Updates score from matches
# - update_score_display(): Updates UI score label
# - draw_debug_grid(): Renders debug visualization

extends Node2D

var GameConstants = preload("res://scripts/game_constants.gd")
var PuyoClass = preload("res://scripts/puyo.gd")
var GameFieldClass = preload("res://scripts/game_field.gd")
var PebbleScene = preload("res://scenes/pebble.tscn")

# Game components
var game_field: GameField
var current_puyo: Puyo = null
var next_puyo_types: Array = []

# Game state
var score: int = 0
var spawn_timer: float = 0.0
var is_spawning: bool = false
var game_over: bool = false
var is_processing_chain: bool = false

# Input handling
var swipe_start_position: Vector2 = Vector2.ZERO
var is_swiping: bool = false
var swipe_side: String = ""
var rotation_accumulator: float = 0.0
var last_swipe_y: float = 0.0

# Initializes the game when scene starts
func _ready():
	randomize()
	
	# Create and setup game field
	game_field = GameFieldClass.new()
	game_field.name = "GameField"
	add_child(game_field)
	
	# Connect game field signals
	game_field.matches_found.connect(_on_matches_found)
	game_field.game_over.connect(_on_game_over)
	
	# Start the game
	prepare_next_puyo()
	spawn_puyo()

# Renders debug visualization if enabled
func _draw():
	if GameConstants.DEBUG_MODE:
		draw_debug_grid()

# Main game update loop
func _process(delta):
	if game_over:
		return
	
	# Handle spawn timer
	if is_spawning:
		spawn_timer -= delta
		if spawn_timer <= 0:
			spawn_puyo()
			is_spawning = false
	
	if GameConstants.DEBUG_MODE:
		queue_redraw()

# Routes input events to appropriate handlers
func _input(event):
	if game_over or is_processing_chain:
		return
	
	if event is InputEventScreenTouch:
		handle_touch(event)
	elif event is InputEventScreenDrag:
		handle_drag(event)
	elif event is InputEventMouseButton:
		handle_mouse_click(event)
	elif event is InputEventKey:
		handle_keyboard(event)

# Handles touch screen input
func handle_touch(event: InputEventScreenTouch):
	if event.pressed:
		swipe_start_position = event.position
		is_swiping = true
		last_swipe_y = event.position.y
		swipe_side = "left" if event.position.x < get_viewport().size.x / 2 else "right"
		
		# Simple tap movement
		if current_puyo and not is_swiping:
			var screen_width = get_viewport().size.x
			if event.position.x < screen_width / 2:
				move_puyo_left()
			else:
				move_puyo_right()
	else:
		is_swiping = false
		rotation_accumulator = 0.0

# Handles swipe gestures for rotation and drop
func handle_drag(event: InputEventScreenDrag):
	if not is_swiping or not current_puyo:
		return
	
	var drag_distance = event.position - swipe_start_position
	
	# Left side: vertical swipe for rotation
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
	
	# Right side: swipe down for drop
	elif swipe_side == "right":
		if drag_distance.y > 50:
			drop_puyo()
			is_swiping = false

# Handles mouse click input
func handle_mouse_click(event: InputEventMouseButton):
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_puyo:
			var screen_width = get_viewport().size.x
			if event.position.x < screen_width / 2:
				move_puyo_left()
			else:
				move_puyo_right()

# Handles keyboard input
func handle_keyboard(event: InputEventKey):
	if not event.pressed or not current_puyo:
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

# Creates and spawns a new puyo pair
func spawn_puyo():
	if game_over:
		return
	
	prepare_next_puyo()
	
	# Create pebbles for the puyo
	var spawn_pos = $SpawnPosition.position
	var pebble1 = create_pebble(next_puyo_types[0], spawn_pos)
	var pebble2 = create_pebble(next_puyo_types[1], Vector2(spawn_pos.x, spawn_pos.y - GameConstants.CELL_SIZE))
	
	# Create and initialize puyo
	current_puyo = PuyoClass.new()
	current_puyo.name = "CurrentPuyo"
	add_child(current_puyo)
	current_puyo.initialize(pebble1, pebble2)
	
	# Connect puyo signals
	current_puyo.puyo_landed.connect(_on_puyo_landed)
	current_puyo.puyo_discarded.connect(_on_puyo_discarded)

# Creates a single pebble instance
# type: Pebble type integer
# pos: Initial world position
# Returns: Created pebble node
func create_pebble(type: int, pos: Vector2) -> Node2D:
	var pebble = PebbleScene.instantiate()
	pebble.position = pos
	
	var sprite_name = GameConstants.PEBBLE_COLORS[type] if type < GameConstants.PEBBLE_COLORS.size() else GameConstants.WILDCARD_PEBBLE
	pebble.initialize(type, sprite_name)
	
	return pebble

# Generates the types for the next puyo pair
func prepare_next_puyo():
	next_puyo_types.clear()
	for i in range(2):
		if randf() < 0.1:  # 10% chance for glowing pebble
			next_puyo_types.append(GameConstants.PebbleType.GLOWING)
		else:
			next_puyo_types.append(randi() % GameConstants.PEBBLE_COLORS.size())

# Sends left movement command to current puyo
func move_puyo_left():
	if current_puyo:
		current_puyo.move_left()

# Sends right movement command to current puyo
func move_puyo_right():
	if current_puyo:
		current_puyo.move_right()

# Sends clockwise rotation command to current puyo
func rotate_puyo_cw():
	if current_puyo:
		current_puyo.rotate_clockwise()

# Sends counter-clockwise rotation command to current puyo
func rotate_puyo_ccw():
	if current_puyo:
		current_puyo.rotate_counter_clockwise()

# Sends drop command to current puyo
func drop_puyo():
	if current_puyo:
		current_puyo.drop()

# Handles puyo landing event
# puyo: The puyo that landed
func _on_puyo_landed(puyo):
	# Puyo will emit discarded signal, which we handle separately
	pass

# Converts puyo pebbles to field elements
# positions: Grid positions of the pebbles
# types: Pebble type integers
func _on_puyo_discarded(positions: Array, types: Array):
	# Get pebbles from puyo before it's destroyed
	var pebbles = current_puyo.discard()
	
	# Add pebbles to field
	for i in range(positions.size()):
		if i < pebbles.size():
			game_field.add_pebble(positions[i], pebbles[i])
	
	# Clear current puyo reference
	current_puyo = null
	
	# Start chain reaction processing
	process_chain_reaction()

# Processes matching and gravity in a chain reaction
func process_chain_reaction():
	is_processing_chain = true
	
	# Process matches
	var match_result = game_field.process_matches()
	
	if match_result["match_count"] > 0:
		# Wait for match animation
		await get_tree().create_timer(0.3).timeout
		
		# Apply gravity
		game_field.apply_gravity()
		
		# Wait for gravity animation
		await get_tree().create_timer(0.5).timeout
		
		# Recursively process more matches
		process_chain_reaction()
	else:
		# No more matches, check game over
		if game_field.check_game_over():
			game_over = true
			print("Game Over! Final Score: ", score)
		else:
			# Schedule next puyo spawn
			is_spawning = true
			spawn_timer = GameConstants.SPAWN_DELAY
		
		is_processing_chain = false

# Updates score when matches are found
# match_count: Number of match groups
# pebble_count: Total pebbles removed
func _on_matches_found(match_count: int, pebble_count: int):
	score += pebble_count * GameConstants.POINTS_PER_PEBBLE
	score += match_count * GameConstants.POINTS_PER_CHAIN
	update_score_display()

# Handles game over signal from field
func _on_game_over():
	game_over = true
	print("Game Over! Final Score: ", score)

# Updates the score display in UI
func update_score_display():
	var score_label = $UI/ScoreLabel
	if score_label:
		score_label.text = "Score: " + str(score)

# Renders debug grid for development
func draw_debug_grid():
	var grid_color = Color(0.3, 0.3, 0.3, 0.5)
	var border_color = Color(0.5, 0.5, 0.5, 0.8)
	var occupied_color = Color(1.0, 0.2, 0.2, 0.3)
	
	# Draw grid lines
	for x in range(GameConstants.GRID_WIDTH + 1):
		var start_pos = GameConstants.GRID_ORIGIN + Vector2(x * GameConstants.CELL_SIZE, 0)
		var end_pos = GameConstants.GRID_ORIGIN + Vector2(x * GameConstants.CELL_SIZE, GameConstants.GRID_HEIGHT * GameConstants.CELL_SIZE)
		draw_line(start_pos, end_pos, grid_color, 1.0)
	
	for y in range(GameConstants.GRID_HEIGHT + 1):
		var start_pos = GameConstants.GRID_ORIGIN + Vector2(0, y * GameConstants.CELL_SIZE)
		var end_pos = GameConstants.GRID_ORIGIN + Vector2(GameConstants.GRID_WIDTH * GameConstants.CELL_SIZE, y * GameConstants.CELL_SIZE)
		draw_line(start_pos, end_pos, grid_color, 1.0)
	
	# Draw border
	var border_rect = Rect2(
		GameConstants.GRID_ORIGIN,
		Vector2(GameConstants.GRID_WIDTH * GameConstants.CELL_SIZE, GameConstants.GRID_HEIGHT * GameConstants.CELL_SIZE)
	)
	draw_rect(border_rect, border_color, false, 2.0)
	
	# Draw occupied cells
	if game_field:
		for x in range(GameConstants.GRID_WIDTH):
			for y in range(GameConstants.GRID_HEIGHT):
				var grid_pos = Vector2i(x, y)
				if not game_field.is_cell_empty(grid_pos):
					var cell_rect = Rect2(
						GameConstants.GRID_ORIGIN + Vector2(x * GameConstants.CELL_SIZE, y * GameConstants.CELL_SIZE),
						Vector2(GameConstants.CELL_SIZE, GameConstants.CELL_SIZE)
					)
					draw_rect(cell_rect, occupied_color, true)
	
	# Draw grid coordinates
	var font = ThemeDB.fallback_font
	var font_size = 10
	for x in range(GameConstants.GRID_WIDTH):
		var text_pos = GameConstants.GRID_ORIGIN + Vector2(x * GameConstants.CELL_SIZE + 5, -5)
		draw_string(font, text_pos, str(x), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	
	for y in range(GameConstants.GRID_HEIGHT):
		var text_pos = GameConstants.GRID_ORIGIN + Vector2(-15, y * GameConstants.CELL_SIZE + 15)
		draw_string(font, text_pos, str(y), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)