extends Node

class_name GridSystem

var grid: Array = []
var GameConstants = preload("res://scripts/game_constants.gd")

func _init():
	reset_grid()

func reset_grid():
	grid = []
	for y in range(GameConstants.GRID_HEIGHT):
		var row = []
		for x in range(GameConstants.GRID_WIDTH):
			row.append(null)
		grid.append(row)

func add_pebble(grid_pos: Vector2i, pebble_type: int) -> bool:
	if not GameConstants.is_valid_grid_position(grid_pos):
		return false
	if grid[grid_pos.y][grid_pos.x] != null:
		return false
	
	grid[grid_pos.y][grid_pos.x] = pebble_type
	return true

func get_pebble(grid_pos: Vector2i):
	if not GameConstants.is_valid_grid_position(grid_pos):
		return null
	return grid[grid_pos.y][grid_pos.x]

func remove_pebble(grid_pos: Vector2i) -> bool:
	if not GameConstants.is_valid_grid_position(grid_pos):
		return false
	grid[grid_pos.y][grid_pos.x] = null
	return true

func is_cell_empty(grid_pos: Vector2i) -> bool:
	if not GameConstants.is_valid_grid_position(grid_pos):
		return false
	return grid[grid_pos.y][grid_pos.x] == null

func can_move_to(grid_pos: Vector2i) -> bool:
	if not GameConstants.is_valid_grid_position(grid_pos):
		return false
	return is_cell_empty(grid_pos)

func check_matches() -> Array:
	var matches = []
	var visited = {}
	
	for y in range(GameConstants.GRID_HEIGHT):
		for x in range(GameConstants.GRID_WIDTH):
			var pos = Vector2i(x, y)
			if grid[y][x] != null and not visited.has(pos):
				var group = find_connected_group(pos, grid[y][x], visited)
				if group.size() >= GameConstants.MATCH_COUNT:
					matches.append(group)
	
	return matches

func find_connected_group(start_pos: Vector2i, pebble_type: int, visited: Dictionary) -> Array:
	var group = []
	var to_check = [start_pos]
	
	while to_check.size() > 0:
		var current = to_check.pop_front()
		
		if visited.has(current):
			continue
			
		var current_type = get_pebble(current)
		if current_type == null:
			continue
			
		if current_type != pebble_type and current_type != GameConstants.PebbleType.GLOWING:
			if pebble_type != GameConstants.PebbleType.GLOWING:
				continue
		
		visited[current] = true
		group.append(current)
		
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

func apply_gravity() -> Array:
	var moved_pebbles = []
	
	for x in range(GameConstants.GRID_WIDTH):
		var write_pos = GameConstants.GRID_HEIGHT - 1
		
		for y in range(GameConstants.GRID_HEIGHT - 1, -1, -1):
			if grid[y][x] != null:
				if y != write_pos:
					grid[write_pos][x] = grid[y][x]
					grid[y][x] = null
					moved_pebbles.append({
						"from": Vector2i(x, y),
						"to": Vector2i(x, write_pos),
						"type": grid[write_pos][x]
					})
				write_pos -= 1
	
	return moved_pebbles

func get_highest_in_column(column: int) -> int:
	if column < 0 or column >= GameConstants.GRID_WIDTH:
		return -1
	
	for y in range(GameConstants.GRID_HEIGHT):
		if grid[y][column] != null:
			return y
	
	return GameConstants.GRID_HEIGHT

func is_game_over() -> bool:
	var spawn_column = 2
	return grid[0][spawn_column] != null or grid[0][spawn_column + 1] != null
