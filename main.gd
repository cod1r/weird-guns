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
var global_mobs: Array[Dictionary] = []

var bullets: Array[Dictionary] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_viewport_rect().size
	$Player.position = $PlayerPosition.position
	$Player.z_index = 1
	$Player/Gun.z_index = 2

func spawn_bullet(trajectory: Vector2) -> void:
	var new_bullet: Node2D = bullet_scene.instantiate()
	new_bullet.position = $Player/Gun.global_position
	new_bullet.position.y -= 10
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
			var bullet := dict["bullet"] as Node2D
			bullet.queue_free()
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
	var directions := global_mobs.map(func(dict):
		var mob := dict["Node2D"] as Node2D
		return (player_position - mob.position).normalized() as Vector2
		)

	for i in range(global_mobs.size()):
		var mob := global_mobs[i]["Node2D"] as Node2D
		mob.get_node("AnimatedSprite2D").flip_h = directions[i].x > 0
		var mob_name := global_mobs[i]["name"] as String
		var speed = mouse_mob_speed \
		if mob_name.contains("Mouse") else (\
			barnacle_mob_speed if mob_name.contains("Barnacle") else bee_mob_speed)
		mob.position += (speed * directions[i] * delta) as Vector2

func on_mob_hit(mob_hit: Node2D, area: Area2D):
	var bullets_areas2d = bullets.map(func(dict: Dictionary):
		return dict["bullet"].get_node("Area2D"))
	var bullet_indx = bullets_areas2d.find(area)
	if bullet_indx != -1:
		var bullet = bullets[bullet_indx]["bullet"] as Node2D
		bullet.queue_free()
		mob_hit.queue_free()
		global_mobs = global_mobs.filter(func(dict):
			return dict["Node2D"] != mob_hit)
		bullets = bullets.filter(func(dict: Dictionary):
			return dict["bullet"].get_node("Area2D") != area)

func _on_mob_mob_spawn() -> void:
	var mobs := [barnacle_mob, mouse_mob, bee_mob] as Array[PackedScene]
	var mob_scene: PackedScene = mobs.pick_random()
	var mob: Node2D = mob_scene.instantiate()

	mob.z_index = 1

	var area2d := mob.get_node("Area2D") as Area2D
	area2d.area_entered.connect(func(area): on_mob_hit(mob, area))

	global_mobs.append({ "Node2D": mob, "name": mob.name })

	var mob_spawn_location = $MobPath/MobSpawnLocation

	mob_spawn_location.progress_ratio = randf()

	mob.position = mob_spawn_location.position

	mob.get_node("AnimatedSprite2D").play()

	add_child(mob)
	mob.show()
