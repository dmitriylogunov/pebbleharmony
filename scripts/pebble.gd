extends Node2D

class_name Pebble

var GameConstants = preload("res://scripts/game_constants.gd")

var pebble_type: int = 0
var is_falling: bool = true
var is_dropping: bool = false
var velocity: Vector2 = Vector2.ZERO
var target_x: float = 0.0
var is_in_puyo: bool = false
var puyo_partner: Node2D = null
var puyo_rotation: float = 0.0

signal landed
signal matched

func _ready():
	set_physics_process(true)

func initialize(type: int, sprite_path: String):
	pebble_type = type
	var sprite = $Sprite2D
	if sprite:
		sprite.texture = load("res://assets/sprites/" + sprite_path + ".png")

func _physics_process(delta):
	if not is_falling:
		return
	
	if is_dropping:
		velocity.y = GameConstants.DROP_SPEED
	else:
		velocity.y = GameConstants.FALL_SPEED
	
	if abs(position.x - target_x) > 1:
		var direction = sign(target_x - position.x)
		velocity.x = direction * GameConstants.HORIZONTAL_SPEED
	else:
		velocity.x = 0
		position.x = target_x
	
	position += velocity * delta
	
	check_landing()

func move_to_x(new_x: float):
	target_x = new_x

func drop():
	is_dropping = true

func check_landing():
	var grid_pos = GameConstants.get_grid_position(position)
	
	if grid_pos.y >= GameConstants.GRID_HEIGHT - 1:
		land()
		return
	
	var below_pos = Vector2i(grid_pos.x, grid_pos.y + 1)
	var expected_y = GameConstants.get_world_position(below_pos).y
	
	if position.y >= expected_y - GameConstants.CELL_SIZE / 2:
		if not can_continue_falling(below_pos):
			land()

func can_continue_falling(below_pos: Vector2i) -> bool:
	var parent = get_parent()
	if parent and parent.has_method("is_cell_empty"):
		return parent.is_cell_empty(below_pos)
	return true

func land():
	is_falling = false
	is_dropping = false
	velocity = Vector2.ZERO
	
	var grid_pos = GameConstants.get_grid_position(position)
	var final_pos = GameConstants.get_world_position(grid_pos)
	position = final_pos
	
	landed.emit()

func snap_to_grid():
	var grid_pos = GameConstants.get_grid_position(position)
	position = GameConstants.get_world_position(grid_pos)

func set_puyo_partner(partner: Node2D):
	puyo_partner = partner
	is_in_puyo = true

func rotate_around_partner(angle: float):
	if not puyo_partner:
		return
	
	var pivot = puyo_partner.position
	var offset = position - pivot
	var rotated = offset.rotated(angle)
	position = pivot + rotated
	puyo_rotation += angle

func separate_from_puyo():
	is_in_puyo = false
	puyo_partner = null
	puyo_rotation = 0.0
