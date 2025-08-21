# GameField.gd - Manages the game playing field, grid state, and static pebbles
#
# Purpose: Maintains the grid state, handles collision detection, manages field pebbles,
#          processes matching logic, and simulates gravity for landed pebbles.
#
# Functions/Methods:
# - _ready(): Initializes the game field
# - reset_grid(): Clears and resets the grid to empty state
# - is_position_valid(grid_pos): Checks if a position is valid and empty
# - is_cell_empty(grid_pos): Checks if a grid cell is empty
# - add_pebble(grid_pos, pebble_node): Adds a pebble to the field at position
# - get_pebble(grid_pos): Returns pebble node at position
# - remove_pebble(grid_pos): Removes pebble from position
# - check_matches(): Finds all matching groups of 4+ pebbles
# - find_connected_group(start_pos, pebble_type, visited): Recursive match finder
# - process_matches(): Finds and removes matching pebbles
# - remove_matched_pebbles(matches): Removes pebbles from field
# - apply_gravity(): Makes pebbles fall to fill empty spaces
# - is_game_over(): Checks if spawn area is blocked
# - get_highest_in_column(column): Gets topmost pebble in column
# - clear_field(): Removes all pebbles from field

extends Node2D

class_name GameField

var GameConstants = preload("res://scripts/game_constants.gd")

# Grid array storing pebble references (null for empty cells)
var grid: Array = []

# Dictionary mapping grid positions to pebble nodes for quick lookup
var field_pebbles: Dictionary = {}

# Signals for game events
signal matches_found(match_count, pebble_count)
signal gravity_applied(moved_count)
signal game_over()

# Initializes the game field when entering scene
func _ready():
	reset_grid()

# Clears and resets the grid to empty state
func reset_grid():
	grid = []
	field_pebbles.clear()
	
	# Initialize empty grid
	for y in range(GameConstants.GRID_HEIGHT):
		var row = []
		for x in range(GameConstants.GRID_WIDTH):
			row.append(null)
		grid.append(row)

# Checks if a grid position is valid for placing a pebble
# grid_pos: Position to check in grid coordinates
# Returns: true if position is valid and empty
func is_position_valid(grid_pos: Vector2i) -> bool:
	if not GameConstants.is_valid_grid_position(grid_pos):
		return false
	return is_cell_empty(grid_pos)

# Checks if a specific grid cell is empty
# grid_pos: Grid position to check
# Returns: true if cell is empty
func is_cell_empty(grid_pos: Vector2i) -> bool:
	if not GameConstants.is_valid_grid_position(grid_pos):
		return false
	return grid[grid_pos.y][grid_pos.x] == null

# Adds a pebble to the field at specified position
# grid_pos: Target grid position
# pebble_node: The pebble node to place
# Returns: true if successfully added
func add_pebble(grid_pos: Vector2i, pebble_node: Node2D) -> bool:
	if not GameConstants.is_valid_grid_position(grid_pos):
		return false
	if grid[grid_pos.y][grid_pos.x] != null:
		return false
	
	# Store in grid
	grid[grid_pos.y][grid_pos.x] = pebble_node
	field_pebbles[grid_pos] = pebble_node
	
	# Ensure pebble is child of field
	if pebble_node.get_parent() != self:
		if pebble_node.get_parent():
			pebble_node.get_parent().remove_child(pebble_node)
		add_child(pebble_node)
	
	# Position pebble at grid location
	pebble_node.position = GameConstants.get_world_position(grid_pos)
	
	return true

# Gets the pebble node at a specific grid position
# grid_pos: Grid position to check
# Returns: Pebble node or null if empty
func get_pebble(grid_pos: Vector2i) -> Node2D:
	if not GameConstants.is_valid_grid_position(grid_pos):
		return null
	return grid[grid_pos.y][grid_pos.x]

# Removes pebble from specified position
# grid_pos: Grid position to clear
# Returns: true if pebble was removed
func remove_pebble(grid_pos: Vector2i) -> bool:
	if not GameConstants.is_valid_grid_position(grid_pos):
		return false
	
	grid[grid_pos.y][grid_pos.x] = null
	
	if field_pebbles.has(grid_pos):
		field_pebbles.erase(grid_pos)
	
	return true

# Finds all matching groups of 4+ connected pebbles
# Returns: Array of match groups (each group is array of positions)
func check_matches() -> Array:
	var matches = []
	var visited = {}
	
	for y in range(GameConstants.GRID_HEIGHT):
		for x in range(GameConstants.GRID_WIDTH):
			var pos = Vector2i(x, y)
			var pebble = grid[y][x]
			if pebble != null and not visited.has(pos):
				var group = find_connected_group(pos, pebble.pebble_type, visited)
				if group.size() >= GameConstants.MATCH_COUNT:
					matches.append(group)
	
	return matches

# Recursively finds connected pebbles of same type
# start_pos: Starting grid position
# pebble_type: Type to match
# visited: Dictionary tracking visited cells
# Returns: Array of connected positions
func find_connected_group(start_pos: Vector2i, pebble_type: int, visited: Dictionary) -> Array:
	var group = []
	var to_check = [start_pos]
	
	while to_check.size() > 0:
		var current = to_check.pop_front()
		
		if visited.has(current):
			continue
		
		var current_pebble = get_pebble(current)
		if current_pebble == null:
			continue
		
		var current_type = current_pebble.pebble_type
		
		# Check type matching (including wildcard/glowing logic)
		if current_type != pebble_type and current_type != GameConstants.PebbleType.GLOWING:
			if pebble_type != GameConstants.PebbleType.GLOWING:
				continue
		
		visited[current] = true
		group.append(current)
		
		# Check all 4 neighbors
		var neighbors = [
			Vector2i(current.x - 1, current.y),
			Vector2i(current.x + 1, current.y),
			Vector2i(current.x, current.y - 1),
			Vector2i(current.x, current.y + 1)
		]
		
		for neighbor in neighbors:
			if GameConstants.is_valid_grid_position(neighbor) and not visited.has(neighbor):
				to_check.append(neighbor)
	
	return group

# Processes matching logic and removes matched pebbles
# Returns: Dictionary with match statistics
func process_matches() -> Dictionary:
	var matches = check_matches()
	
	if matches.size() == 0:
		return {"match_count": 0, "pebble_count": 0}
	
	var total_pebbles = 0
	for match_group in matches:
		total_pebbles += match_group.size()
	
	remove_matched_pebbles(matches)
	
	# Emit signal for scoring
	matches_found.emit(matches.size(), total_pebbles)
	
	return {"match_count": matches.size(), "pebble_count": total_pebbles}

# Removes matched pebbles from the field
# matches: Array of match groups to remove
func remove_matched_pebbles(matches: Array):
	for match_group in matches:
		for grid_pos in match_group:
			var pebble = get_pebble(grid_pos)
			if pebble:
				# Remove from grid
				remove_pebble(grid_pos)
				# Free the pebble node
				if is_instance_valid(pebble):
					pebble.queue_free()

# Applies gravity to make pebbles fall into empty spaces
# Returns: Number of pebbles that moved
func apply_gravity() -> int:
	var moved_count = 0
	
	# Process each column from bottom to top
	for x in range(GameConstants.GRID_WIDTH):
		var write_pos = GameConstants.GRID_HEIGHT - 1
		
		# Scan from bottom to top
		for y in range(GameConstants.GRID_HEIGHT - 1, -1, -1):
			var pebble = grid[y][x]
			if pebble != null:
				if y != write_pos:
					# Move pebble down
					var old_pos = Vector2i(x, y)
					var new_pos = Vector2i(x, write_pos)
					
					# Update grid
					grid[write_pos][x] = pebble
					grid[y][x] = null
					
					# Update dictionary
					field_pebbles.erase(old_pos)
					field_pebbles[new_pos] = pebble
					
					# Update visual position
					pebble.position = GameConstants.get_world_position(new_pos)
					
					moved_count += 1
				write_pos -= 1
	
	if moved_count > 0:
		gravity_applied.emit(moved_count)
	
	return moved_count

# Checks if the game is over (spawn area blocked)
# Returns: true if game over condition is met
func is_game_over() -> bool:
	# Check if spawn columns are blocked at top
	var spawn_column = 2  # Middle column for spawn
	var is_over = grid[0][spawn_column] != null or grid[0][spawn_column + 1] != null
	
	if is_over:
		game_over.emit()
	
	return is_over

# Gets the highest occupied row in a column
# column: Column index to check
# Returns: Row index of highest pebble, or GRID_HEIGHT if empty
func get_highest_in_column(column: int) -> int:
	if column < 0 or column >= GameConstants.GRID_WIDTH:
		return -1
	
	for y in range(GameConstants.GRID_HEIGHT):
		if grid[y][column] != null:
			return y
	
	return GameConstants.GRID_HEIGHT

# Clears all pebbles from the field
func clear_field():
	# Free all pebble nodes
	for pos in field_pebbles:
		var pebble = field_pebbles[pos]
		if is_instance_valid(pebble):
			pebble.queue_free()
	
	field_pebbles.clear()
	reset_grid()