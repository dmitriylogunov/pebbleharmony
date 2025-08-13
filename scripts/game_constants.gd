extends Node

const GRID_WIDTH = 6
const GRID_HEIGHT = 12
const CELL_SIZE = 64
const PEBBLE_TEXTURE_SIZE = 144
const PEBBLE_SCALE = float(CELL_SIZE) / float(PEBBLE_TEXTURE_SIZE)

const UI_MARGIN = 50
const SCREEN_WIDTH = 720
const SCREEN_HEIGHT = 1280

const GRID_PIXEL_WIDTH = GRID_WIDTH * CELL_SIZE
const GRID_PIXEL_HEIGHT = GRID_HEIGHT * CELL_SIZE

const GRID_BACKGROUND_WIDTH = SCREEN_WIDTH - (UI_MARGIN * 2)
const GRID_BACKGROUND_HEIGHT = SCREEN_HEIGHT - (UI_MARGIN * 2)

const GRID_ORIGIN = Vector2(
	UI_MARGIN + (GRID_BACKGROUND_WIDTH - GRID_PIXEL_WIDTH) / 2,
	UI_MARGIN + (GRID_BACKGROUND_HEIGHT - GRID_PIXEL_HEIGHT) / 2
)

const FALL_SPEED = 80.0
const HORIZONTAL_SPEED = 300.0
const DROP_SPEED = 500.0

const SPAWN_DELAY = 0.5

const MATCH_COUNT = 4

const POINTS_PER_PEBBLE = 10
const POINTS_PER_CHAIN = 50

const PEBBLE_COLORS = [
	"pebble-black",
	"pebble-blue",
	"pebble-gray",
	"pebble-green",
	"pebble-white"
]

const WILDCARD_PEBBLE = "pebble-glowing"

enum PebbleType {
	BLACK,
	BLUE,
	GRAY,
	GREEN,
	WHITE,
	GLOWING
}

static func get_grid_position(world_pos: Vector2) -> Vector2i:
	var relative_pos = world_pos - GRID_ORIGIN
	var grid_x = int(relative_pos.x / CELL_SIZE)
	var grid_y = int(relative_pos.y / CELL_SIZE)
	return Vector2i(grid_x, grid_y)

static func get_world_position(grid_pos: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(
		grid_pos.x * CELL_SIZE + CELL_SIZE / 2,
		grid_pos.y * CELL_SIZE + CELL_SIZE / 2
	)

static func is_valid_grid_position(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < GRID_WIDTH and \
		   grid_pos.y >= 0 and grid_pos.y < GRID_HEIGHT
