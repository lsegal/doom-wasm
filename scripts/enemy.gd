class_name Hellspawn
extends CharacterBody3D

signal died(enemy: Hellspawn)

var player: CharacterBody3D
var game: Node
var alive := true
var attack_cooldown := 0.0
var sprite: Sprite3D

var idle_texture := preload("res://assets/generated/demon_idle.png")
var attack_texture := preload("res://assets/generated/demon_attack.png")
var hurt_texture := preload("res://assets/generated/demon_hurt.png")
var dead_texture := preload("res://assets/generated/demon_dead.png")


func setup(target: CharacterBody3D, owner_game: Node) -> void:
	player = target
	game = owner_game


func _ready() -> void:
	sprite = Sprite3D.new()
	sprite.texture = idle_texture
	sprite.position.y = 0.15
	sprite.pixel_size = 0.0065
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	add_child(sprite)

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.7
	collision.shape = shape
	collision.position.y = 0.2
	add_child(collision)


func _physics_process(delta: float) -> void:
	if not alive or not is_instance_valid(player):
		return

	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	var offset := player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()

	if distance > 1.25:
		velocity = offset.normalized() * 1.4
		sprite.texture = idle_texture
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		sprite.texture = attack_texture
		if attack_cooldown <= 0.0:
			game.take_damage(8)
			attack_cooldown = 0.7


func damage() -> void:
	if not alive:
		return
	alive = false
	velocity = Vector3.ZERO
	sprite.texture = hurt_texture
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	died.emit(self)
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(sprite):
		sprite.texture = dead_texture
		sprite.position.y = -0.42
