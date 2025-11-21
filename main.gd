extends Node2D

var screen_size
@export var mouse_mob: PackedScene
@export var barnacle_mob: PackedScene
@export var bee_mob: PackedScene
const mouse_mob_speed := 400
const barnacle_mob_speed := 200
const bee_mob_speed := 250
var global_mobs: Array[Node2D] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_viewport_rect().size
	$Player.position = $PlayerPosition.position

@export var player_speed = 300
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
	else:
		$Player/AnimatedSprite2D.stop()

	if (w): velocity.y -= 1
	if (a): velocity.x -= 1
	if (s): velocity.y += 1
	if (d): velocity.x += 1

	$Player.position += velocity * player_speed * delta
	$Player.position = $Player.position.clamp(Vector2.ZERO, screen_size)

	$Player/AnimatedSprite2D.flip_h = velocity.x < 0

	update_mob_positions(delta)

func update_mob_positions(delta: float):
	var player_position := $Player.position as Vector2
	var directions := global_mobs.map(func(mob):
		return (player_position - mob.position).normalized() as Vector2
		)

	const speeds = {
		"Barnacle":barnacle_mob_speed,
		"Bee":bee_mob_speed,
		"Mouse":mouse_mob_speed
	}

	for i in range(global_mobs.size()):
		var key = global_mobs[i].name.get_slice("Mob", 0)

		global_mobs[i].get_child(0).flip_h = \
			directions[i].x > 0

		global_mobs[i].position += \
			(speeds[key] * directions[i] * delta) as Vector2

func _on_mob_mob_spawn() -> void:
	var mobs := [bee_mob, barnacle_mob, mouse_mob] as Array[PackedScene]
	var mob_scene: PackedScene = mobs.pick_random()
	var mob = mob_scene.instantiate()

	global_mobs.append(mob)

	var mob_spawn_location = $MobPath/MobSpawnLocation

	mob_spawn_location.progress_ratio = randf()

	mob.position = mob_spawn_location.position

	#get_child(0) is AnimatedSprite2D
	mob.get_child(0).play()
	#adding a number here because if I add it without a unique name, godot will rename it to something weird
	mob.name = mob.name + String.num_int64(global_mobs.size())
	add_child(mob)
	mob.show()
