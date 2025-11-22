extends Node2D

var screen_size
@export var mouse_mob: PackedScene
@export var barnacle_mob: PackedScene
@export var bee_mob: PackedScene

@export var bullet_scene: PackedScene
const mouse_mob_speed := 400
const barnacle_mob_speed := 200
const bee_mob_speed := 250
var bullet_speed = 400
var global_mobs: Array[Node2D] = []

var bullets: Array[Dictionary] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_viewport_rect().size
	$Player.position = $PlayerPosition.position
	$Player.z_index = 1
	$Player/Gun.z_index = 2

func spawn_bullet(trajectory: Vector2) -> void:
	var new_bullet: Node2D = bullet_scene.instantiate()
	new_bullet.position = $Player.position
	new_bullet.z_index = 0
	new_bullet.name += String.num_int64((get_children()).size())
	new_bullet.transform = new_bullet.transform.rotated_local(acos(trajectory.x) * sign(trajectory.y))
	bullets.append({"bullet": new_bullet, "trajectory": trajectory})
	add_child(new_bullet)

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
		$Player/Body.animation = "character_walk"
		$Player/Body.play()
	else:
		$Player/Body.stop()

	if (w): velocity.y -= 1
	if (a): velocity.x -= 1
	if (s): velocity.y += 1
	if (d): velocity.x += 1

	var vel_norm = velocity.normalized()

	$Player.position += vel_norm * player_speed * delta
	$Player.position = $Player.position.clamp(Vector2.ZERO, screen_size)

	$Player/Body.flip_h = velocity.x < 0

	update_gun_position()

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse_position = get_viewport().get_mouse_position()
		spawn_bullet((mouse_position - $Player.position).normalized())

	update_mob_positions(delta)

	for dict in bullets:
		var bullet = dict["bullet"]
		var trajectory = dict["trajectory"]
		bullet.position += trajectory * delta * bullet_speed

	var viewport = get_viewport_rect()
	bullets = bullets.filter(func(dict: Dictionary):
		var encloses = viewport.encloses(dict["bullet"].get_viewport_rect())
		if not encloses:
			remove_child(dict["bullet"])
		return encloses)


func update_gun_position():
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var gun: Sprite2D = $Player/Gun

	var diff_vec: Vector2 = (mouse_position - $Player.position).normalized()

	var current_rotation = gun.transform.get_rotation()
	var diff_rotation = acos(diff_vec.x) * sign(diff_vec.y) - current_rotation
	gun.transform = gun.transform.rotated(diff_rotation)
	var current_gun_translation = gun.transform.get_origin()
	var diff_translation = diff_vec * 50 - current_gun_translation
	gun.transform = gun.transform.translated(diff_translation)
	gun.flip_v = gun.position.x < 0

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

		global_mobs[i].get_child(0).flip_h = directions[i].x > 0

		global_mobs[i].position += (speeds[key] * directions[i] * delta) as Vector2

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
