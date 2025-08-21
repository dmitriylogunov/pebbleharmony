# Pebble.gd - Visual representation of a game piece
# 
# Purpose: Simple visual element that displays a colored pebble sprite.
#          Has no game logic - just stores type and manages appearance.
#
# Functions/Methods:
# - _ready(): Called when node enters scene
# - initialize(type, sprite_path): Sets up pebble type and sprite
# - get_type(): Returns the pebble's type

extends Node2D

class_name Pebble

var GameConstants = preload("res://scripts/game_constants.gd")

# The type/color of this pebble
var pebble_type: int = 0

# Called when node enters the scene tree
func _ready():
	pass

# Initializes the pebble with a specific type and sprite
# type: Integer representing the pebble type/color
# sprite_path: Path to the sprite image file (without extension)
func initialize(type: int, sprite_path: String):
	pebble_type = type
	var sprite = $Sprite2D
	if sprite:
		sprite.texture = load("res://assets/sprites/" + sprite_path + ".png")

# Returns the pebble's type
func get_type() -> int:
	return pebble_type