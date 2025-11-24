extends Node2D

var screen_size

@export var mouse_mob: PackedScene
@export var barnacle_mob: PackedScene
@export var bee_mob: PackedScene

@export var bullet_scene: PackedScene

const mouse_mob_speed := 400
const barnacle_mob_speed := 200
const bee_mob_speed := 250
const bullet_speed := 400

var player_health := 100

const barnacle_mob_damage := 15
const bee_mob_damage := 10
const mouse_mob_damage := 5

var global_mobs: Array[Dictionary] = []

var bullets: Array[Dictionary] = []

var mobs_killed = 0

func restart_game():
	player_health = 100
	var rect := $Player/HealthBarContainer/ActualHealthBar.get_rect() as Rect2
	var width := rect.size.x
	$Player/HealthBarContainer/ActualHealthBar.translate(Vector2(width, 0))
	$Mob/MobSpawnTimer.start()
	$EndScreen.hide()
	$Player.position = $PlayerPosition.position

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$EndScreen.hide()
	var restart_btn := $EndScreen/Restart as Button
	restart_btn.pressed.connect(restart_game)
	var label := $CurrentGameInfo/PlayerHealth as Label
	label.text = "Player Health: " + String.num_int64(player_health)
	screen_size = get_viewport_rect().size
	$Player.position = $PlayerPosition.position
	$Player.z_index = 1
	$Player/Gun.z_index = 2

func spawn_bullet(trajectory: Vector2) -> void:
	var new_bullet: Node2D = bullet_scene.instantiate()
	new_bullet.position = $Player/Gun.global_position
	new_bullet.position.y -= 10
	new_bullet.z_index = 0
	new_bullet.transform = new_bullet.transform.rotated_local(acos(trajectory.x) * sign(trajectory.y))
	bullets.append({"bullet": new_bullet, "trajectory": trajectory})
	add_child(new_bullet)

var last_time_shot = Time.get_ticks_msec()

@export var player_speed = 300

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if player_health <= 0:
		$Mob/MobSpawnTimer.stop()
		$EndScreen.show()
		for dict in global_mobs:
			var mob := dict["Node2D"] as Node2D
			mob.queue_free()

		for dict in bullets:
			var bullet = dict["bullet"] as Node2D
			bullet.queue_free()

		global_mobs = []
		bullets = []
		return

	var keys := [
		Input.is_action_pressed("w_key"),
		Input.is_action_pressed("a_key"),
		Input.is_action_pressed("s_key"),
		Input.is_action_pressed("d_key")
	] as Array[bool]

	var w := keys[0]; var a := keys[1]; var s := keys[2]; var d := keys[3];

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

	var time = Time.get_ticks_msec()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and time - last_time_shot > 0.5 * 1000:
		last_time_shot = time
		var mouse_position = get_viewport().get_mouse_position()
		spawn_bullet((mouse_position - $Player.position).normalized())

	update_mob_positions(delta)

	for dict in bullets:
		var bullet := dict["bullet"] as Node2D
		var trajectory := dict["trajectory"] as Vector2
		bullet.position += trajectory * delta * bullet_speed

	var viewport = get_viewport_rect()
	bullets = bullets.filter(func(dict: Dictionary):
		var bullet := dict["bullet"] as Node2D
		var encloses := viewport.encloses(bullet.get_viewport_rect())
		if not encloses:
			bullet.queue_free()
		return encloses)

func update_gun_position() -> void:
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

func update_mob_positions(delta: float) -> void:
	var player_position := $Player.position as Vector2
	var directions := global_mobs.map(func(dict) -> Vector2:
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

func alter_health_bar(node: Node2D, decrease_percentage: float):
	var health_bar := node.get_node("HealthBarContainer/ActualHealthBar") as Sprite2D
	var rect := health_bar.get_rect()
	var width := rect.size.x
	var shift_amt := width * decrease_percentage as float
	health_bar.translate(Vector2(-shift_amt, 0))

func on_mob_hit(mob_info: Dictionary, area: Area2D) -> void:
	var bullets_areas2d = bullets.map(func(dict: Dictionary) -> Area2D:
		return dict["bullet"].get_node("Area2D"))

	var bullet_indx := bullets_areas2d.find(area)

	if bullet_indx != -1:
		var mob_hit := mob_info["Node2D"] as Node2D
		$GunSound.play()
		var bullet := bullets[bullet_indx]["bullet"] as Node2D
		bullet.queue_free()
		mob_info["health"] -= 50
		var mob_health := mob_info["health"] as float
		alter_health_bar(mob_hit, 50.0 / get_mob_health(mob_info["name"]))
		if mob_health <= 0:
			mob_hit.queue_free()


		global_mobs = global_mobs.filter(func(dict) -> bool:
			var health := dict["health"] as int
			return health > 0)

		bullets = bullets.filter(func(dict: Dictionary) -> bool:
			var bullet_inner := dict["bullet"] as Node2D
			return bullet_inner.get_node("Area2D") != area)

func on_character_hit(mob_type: String, _body: Node2D):
	var dmg: int
	match mob_type:
		"BarnacleMob":
			player_health -= barnacle_mob_damage
			dmg = barnacle_mob_damage
		"BeeMob":
			player_health -= bee_mob_damage
			dmg = bee_mob_damage
		"MouseMob":
			player_health -= mouse_mob_damage
			dmg = mouse_mob_damage

	var label := $CurrentGameInfo/PlayerHealth as Label
	var splitted := label.text.split(":")
	splitted[1] = String.num_int64(max(0, player_health))
	label.text = ": ".join(splitted)

	var player := $Player as Node2D

	alter_health_bar(player, dmg as float / 100)

func get_mob_health(mob_type: String) -> int:
	var health: int
	match mob_type:
		"BarnacleMob": health = 100
		"BeeMob": health = 75
		"MouseMob": health = 50
	return health

func _on_mob_mob_spawn() -> void:
	var mobs := [barnacle_mob] as Array[PackedScene]
	var mob_scene: PackedScene = mobs.pick_random()
	var mob: Node2D = mob_scene.instantiate()

	mob.z_index = 1
	var mob_name = mob.name
	var area2d := mob.get_node("Area2D") as Area2D

	var health := get_mob_health(mob_name)

	var mob_info := { "Node2D": mob, "name": mob.name, "health": health }
	global_mobs.append(mob_info)

	area2d.area_entered.connect(func(area): on_mob_hit(mob_info, area))
	area2d.body_entered.connect(func(body): on_character_hit(mob_name, body))

	var mob_spawn_location = $MobPath/MobSpawnLocation

	mob_spawn_location.progress_ratio = randf()

	mob.position = mob_spawn_location.position

	mob.get_node("AnimatedSprite2D").play()
	add_child(mob)
	mob.show()
