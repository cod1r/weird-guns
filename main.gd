extends Node2D

var screen_size
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_viewport_rect().size

@export var player_speed = 400
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var keys = [
		Input.is_action_pressed("w_key"),
		Input.is_action_pressed("a_key"),
		Input.is_action_pressed("s_key"),
		Input.is_action_pressed("d_key")
	]
	var w = keys[0]; var a = keys[1]; var s = keys[2]; var d = keys[3];
	var velocity = Vector2.ZERO
	if (w || a || s || d):
		$Player/AnimatedSprite2D.animation = "character_walk"
		$Player/AnimatedSprite2D.play()
	if (w): velocity.y -= 1
	if (a): velocity.x -= 1
	if (s): velocity.y += 1
	if (d): velocity.x += 1
	
	$Player.position += velocity * player_speed
	$Player.position = $Player.position.clamp(Vector2.ZERO, screen_size)
	
	if velocity.x != 0:
		$Player/AnimatedSprite2D.flip_h = velocity.x < 0
