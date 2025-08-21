# Puyo.gd - Manages a pair of falling pebbles and their movement/rotation
#
# Purpose: Controls a two-pebble unit including physics, rotation, movement,
#          collision detection, and conversion to field elements upon landing.
#
# Functions/Methods:
# - _ready(): Initializes the puyo and physics processing
# - _physics_process(delta): Handles falling physics and movement
# - initialize(pebble1, pebble2): Sets up the puyo with two pebbles
# - move_left(): Moves the puyo left if possible
# - move_right(): Moves the puyo right if possible
# - rotate_clockwise(): Rotates the puyo 90 degrees clockwise
# - rotate_counter_clockwise(): Rotates the puyo 90 degrees counter-clockwise
# - rotate_puyo(angle): Internal rotation implementation
# - drop(): Activates fast drop mode
# - can_move_to(new_positions): Checks if puyo can move to positions
# - can_rotate_to(new_positions): Validates rotation positions
# - try_wall_kick(pivot_grid, new_offset): Attempts wall kick for rotation
# - check_landing(): Checks if puyo should land
# - land(): Finalizes landing and emits signals
# - get_grid_positions(): Returns current grid positions of pebbles
# - update_target_x(x_offset): Updates horizontal target for smooth movement

extends Node2D

class_name Puyo

var GameConstants = preload("res://scripts/game_constants.gd")

# Child pebble references
var pebbles: Array = []
var pivot_pebble: Node2D = null
var rotating_pebble: Node2D = null

# Movement and physics
var velocity: Vector2 = Vector2.ZERO
var target_x: float = 0.0
var is_falling: bool = true
var is_dropping: bool = false
var is_active: bool = true

# Signals for game communication
signal puyo_landed(puyo)
signal puyo_discarded(grid_positions, pebble_types)

# Initializes physics processing when entering scene
func _ready():
	set_physics_process(true)

# Physics update: handles falling and smooth horizontal movement
# delta: Frame time for smooth movement
func _physics_process(delta):
	if not is_active or not is_falling:
		return
	
	# Set vertical speed based on drop mode
	if is_dropping:
		velocity.y = GameConstants.DROP_SPEED
	else:
		velocity.y = GameConstants.FALL_SPEED
	
	# Smooth horizontal movement towards target
	if abs(position.x - target_x) > 1:
		var direction = sign(target_x - position.x)
		velocity.x = direction * GameConstants.HORIZONTAL_SPEED
	else:
		velocity.x = 0
		position.x = target_x
	
	# Apply velocity to puyo position
	position += velocity * delta
	
	# Update child pebble positions relative to puyo
	for pebble in pebbles:
		if pebble:
			pebble.position = pebble.position  # Pebbles move with their parent
	
	# Check if we should land
	check_landing()

# Initializes the puyo with two pebble nodes
# pebble1: The pivot pebble (usually bottom)
# pebble2: The rotating pebble (usually top)
func initialize(pebble1: Node2D, pebble2: Node2D):
	pebbles = [pebble1, pebble2]
	pivot_pebble = pebble1
	rotating_pebble = pebble2
	
	# Store initial positions
	var pivot_pos = pebble1.position
	var rotating_pos = pebble2.position
	
	# Set puyo position to pivot position
	position = pivot_pos
	target_x = position.x
	
	# Add pebbles as children
	if pebble1.get_parent():
		pebble1.get_parent().remove_child(pebble1)
	if pebble2.get_parent():
		pebble2.get_parent().remove_child(pebble2)
	
	add_child(pebble1)
	add_child(pebble2)
	
	# Set pebble positions relative to puyo
	pebble1.position = Vector2.ZERO
	pebble2.position = rotating_pos - pivot_pos

# Moves the puyo left by one grid cell
func move_left():
	if not is_active:
		return false
	
	var new_positions = []
	for pebble in pebbles:
		var world_pos = global_position + pebble.position - Vector2(GameConstants.CELL_SIZE, 0)
		new_positions.append(GameConstants.get_grid_position(world_pos))
	
	if can_move_to(new_positions):
		update_target_x(-GameConstants.CELL_SIZE)
		return true
	return false

# Moves the puyo right by one grid cell
func move_right():
	if not is_active:
		return false
	
	var new_positions = []
	for pebble in pebbles:
		var world_pos = global_position + pebble.position + Vector2(GameConstants.CELL_SIZE, 0)
		new_positions.append(GameConstants.get_grid_position(world_pos))
	
	if can_move_to(new_positions):
		update_target_x(GameConstants.CELL_SIZE)
		return true
	return false

# Updates horizontal target for smooth movement
# x_offset: Horizontal offset to apply
func update_target_x(x_offset: float):
	target_x += x_offset

# Rotates the puyo 90 degrees clockwise around the pivot
func rotate_clockwise():
	if not is_active:
		return false
	return rotate_puyo(PI / 2)

# Rotates the puyo 90 degrees counter-clockwise around the pivot
func rotate_counter_clockwise():
	if not is_active:
		return false
	return rotate_puyo(-PI / 2)

# Internal rotation logic handling both directions
# angle: Rotation angle in radians (positive = clockwise)
func rotate_puyo(angle: float) -> bool:
	if pebbles.size() != 2:
		return false
	
	# Get current world positions
	var pivot_world = global_position + pivot_pebble.position
	var rotating_world = global_position + rotating_pebble.position
	
	# Get grid positions
	var pivot_grid = GameConstants.get_grid_position(pivot_world)
	var rotating_grid = GameConstants.get_grid_position(rotating_world)
	
	# Calculate the offset from pivot to rotating pebble
	var offset = rotating_grid - pivot_grid
	
	# Calculate new offset after rotation
	# Clockwise (angle > 0): (x,y) -> (-y,x)
	# Counter-clockwise (angle < 0): (x,y) -> (y,-x)
	var new_offset: Vector2i
	if angle > 0:  # Clockwise
		new_offset = Vector2i(-offset.y, offset.x)
	else:  # Counter-clockwise
		new_offset = Vector2i(offset.y, -offset.x)
	
	var new_grid_pos = pivot_grid + new_offset
	
	# Try direct rotation first
	if can_rotate_to([pivot_grid, new_grid_pos]):
		# Apply rotation to rotating pebble's local position
		var new_world_pos = GameConstants.get_world_position(new_grid_pos)
		rotating_pebble.position = new_world_pos - global_position
		return true
	
	# Try wall kick if direct rotation fails
	return try_wall_kick(pivot_grid, new_offset)

# Attempts wall kick rotation when normal rotation is blocked
# pivot_grid: Current pivot position in grid
# new_offset: Desired offset for rotating pebble after rotation
func try_wall_kick(pivot_grid: Vector2i, new_offset: Vector2i) -> bool:
	# Try different kick offsets
	for kick_offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
		var new_pivot_grid = pivot_grid + kick_offset
		var new_rotating_grid = new_pivot_grid + new_offset
		
		# Check if both positions are valid after kick
		if can_rotate_to([new_pivot_grid, new_rotating_grid]):
			# Apply the kick to puyo position
			var kick_world = Vector2(kick_offset.x * GameConstants.CELL_SIZE, 
									 kick_offset.y * GameConstants.CELL_SIZE)
			position += kick_world
			target_x = position.x
			
			# Update rotating pebble position
			var new_rotating_world = GameConstants.get_world_position(new_rotating_grid)
			rotating_pebble.position = new_rotating_world - global_position
			return true
	
	return false

# Activates fast drop mode
func drop():
	if not is_active:
		return
	
	is_dropping = true

# Checks if the puyo can move to new grid positions
# new_positions: Array of grid positions to check
# Returns: true if all positions are valid
func can_move_to(new_positions: Array) -> bool:
	var parent = get_parent()
	if not parent:
		return true
	
	var game_field = parent.get("game_field")
	if not game_field:
		return true
	
	for grid_pos in new_positions:
		if not game_field.is_position_valid(grid_pos):
			return false
	
	return true

# Validates if rotation to new positions is possible
# new_positions: Array of grid positions to check
# Returns: true if all positions are valid
func can_rotate_to(new_positions: Array) -> bool:
	var parent = get_parent()
	if not parent:
		return true
	
	var game_field = parent.get("game_field")
	if not game_field:
		return true
	
	for grid_pos in new_positions:
		if not game_field.is_position_valid(grid_pos):
			return false
	
	return true

# Checks if the puyo should stop falling
func check_landing():
	var parent = get_parent()
	if not parent:
		return
	
	var game_field = parent.get("game_field")
	if not game_field:
		return
	
	# Check each pebble's position below
	for pebble in pebbles:
		var world_pos = global_position + pebble.position
		var grid_pos = GameConstants.get_grid_position(world_pos)
		
		# Check if at bottom of grid
		if grid_pos.y >= GameConstants.GRID_HEIGHT - 1:
			land()
			return
		
		# Check position below
		var below_pos = Vector2i(grid_pos.x, grid_pos.y + 1)
		var expected_y = GameConstants.get_world_position(below_pos).y
		
		# Check if we're close enough to the cell below
		if world_pos.y >= expected_y - GameConstants.CELL_SIZE / 2:
			if not game_field.is_cell_empty(below_pos):
				land()
				return

# Finalizes landing and converts to field elements
func land():
	if not is_active:
		return
	
	is_active = false
	is_falling = false
	velocity = Vector2.ZERO
	
	# Snap to grid positions
	var grid_positions = get_grid_positions()
	for i in range(pebbles.size()):
		if i < grid_positions.size():
			var world_pos = GameConstants.get_world_position(grid_positions[i])
			pebbles[i].position = world_pos - global_position
	
	# Emit landing signal
	puyo_landed.emit(self)
	
	# Prepare data for discarding
	var pebble_types = []
	for pebble in pebbles:
		pebble_types.append(pebble.pebble_type)
	
	# Emit discard signal for game field to handle
	puyo_discarded.emit(grid_positions, pebble_types)

# Returns current grid positions of both pebbles
func get_grid_positions() -> Array:
	var positions = []
	for pebble in pebbles:
		var world_pos = global_position + pebble.position
		positions.append(GameConstants.get_grid_position(world_pos))
	return positions

# Converts puyo to field elements and removes it
func discard():
	# Remove pebbles from puyo and return them for field to manage
	var discarded_pebbles = []
	for pebble in pebbles:
		# Convert pebble position to world position before removing
		pebble.global_position = global_position + pebble.position
		remove_child(pebble)
		discarded_pebbles.append(pebble)
	
	pebbles.clear()
	queue_free()
	
	return discarded_pebbles
