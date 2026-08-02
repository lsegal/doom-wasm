extends Node3D

const CELL := 2.0
const WALL_HEIGHT := 2.4
const PLAYER_SPEED := 5.2
const MOUSE_SENSITIVITY := 0.0022

const LEVEL := [
	"1111111111111111",
	"1000000200000001",
	"1033000200444001",
	"1030022200400001",
	"1030000000402201",
	"1000110030002001",
	"1220100333020001",
	"1000104000000001",
	"1030004440222001",
	"1033300000002001",
	"1000001103300001",
	"1022201003004401",
	"1000200003004001",
	"1000200222004001",
	"1000000000000001",
	"1111111111111111",
]

const ENEMY_POSITIONS := [
	Vector3(5.5, 0.9, 2.5),
	Vector3(9.5, 0.9, 4.5),
	Vector3(13.5, 0.9, 6.5),
	Vector3(3.5, 0.9, 10.5),
	Vector3(8.5, 0.9, 12.5),
	Vector3(13.5, 0.9, 14.0),
]

var player: CharacterBody3D
var camera: Camera3D
var weapon: TextureRect
var health_label: Label
var enemies_label: Label
var fps_label: Label
var message_label: Label
var capture_hint: Label
var health := 100
var enemies_remaining := 0
var pitch := 0.0
var can_fire := true
var fps_elapsed := 0.0
var fps_frames := 0

var weapon_idle := preload("res://assets/generated/weapon_idle.png")
var weapon_fire := preload("res://assets/generated/weapon_fire.png")
var wall_textures := [
	preload("res://assets/generated/wall_brick.png"),
	preload("res://assets/generated/wall_steel.png"),
	preload("res://assets/generated/wall_moss.png"),
	preload("res://assets/generated/wall_tan.png"),
]


func _ready() -> void:
	_build_environment()
	_build_level()
	_build_player()
	_build_enemies()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if OS.has_feature("web") else Input.MOUSE_MODE_CAPTURED


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("100503")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8f3b2d")
	environment.ambient_light_energy = 0.38
	environment.fog_enabled = true
	environment.fog_light_color = Color("35100b")
	environment.fog_density = 0.018
	world_environment.environment = environment
	add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.light_color = Color("ff8b5b")
	light.light_energy = 0.65
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.shadow_enabled = true
	add_child(light)


func _material(texture: Texture2D, emission := Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.roughness = 0.88
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 0.35
	return material


func _build_level() -> void:
	var collision_root := StaticBody3D.new()
	collision_root.name = "LevelCollision"
	add_child(collision_root)

	var material_cache: Array[StandardMaterial3D] = []
	for texture in wall_textures:
		material_cache.append(_material(texture))

	for z in LEVEL.size():
		for x in LEVEL[z].length():
			var kind: int = LEVEL[z].substr(x, 1).to_int()
			if kind == 0:
				continue

			var wall := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(CELL, WALL_HEIGHT, CELL)
			mesh.material = material_cache[clampi(kind - 1, 0, 3)]
			wall.mesh = mesh
			wall.position = Vector3(x * CELL, WALL_HEIGHT * 0.5, z * CELL)
			add_child(wall)

			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = mesh.size
			collision.shape = shape
			collision.position = wall.position
			collision_root.add_child(collision)

	var floor_mesh := MeshInstance3D.new()
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(LEVEL[0].length() * CELL, LEVEL.size() * CELL)
	var floor_material := _material(load("res://assets/generated/floor.png"))
	floor_material.uv1_scale = Vector3(10, 10, 10)
	floor_plane.material = floor_material
	floor_mesh.mesh = floor_plane
	floor_mesh.position = Vector3((LEVEL[0].length() - 1) * CELL * 0.5, 0, (LEVEL.size() - 1) * CELL * 0.5)
	add_child(floor_mesh)

	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(LEVEL[0].length() * CELL, 0.2, LEVEL.size() * CELL)
	floor_collision.shape = floor_shape
	floor_collision.position = floor_mesh.position - Vector3(0, 0.1, 0)
	collision_root.add_child(floor_collision)

	var ceiling := MeshInstance3D.new()
	var ceiling_plane := PlaneMesh.new()
	ceiling_plane.size = floor_plane.size
	var ceiling_material := _material(load("res://assets/generated/ceiling.png"), Color("54170e"))
	ceiling_material.cull_mode = BaseMaterial3D.CULL_FRONT
	ceiling_material.uv1_scale = Vector3(8, 8, 8)
	ceiling_plane.material = ceiling_material
	ceiling.mesh = ceiling_plane
	ceiling.position = floor_mesh.position + Vector3(0, WALL_HEIGHT, 0)
	add_child(ceiling)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(1.7 * CELL, 0.9, 1.7 * CELL)
	player.rotation.y = -0.15
	add_child(player)

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.7
	collision.shape = shape
	player.add_child(collision)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position.y = 0.58
	camera.fov = 76
	camera.current = true
	player.add_child(camera)


func _build_enemies() -> void:
	for position_2d in ENEMY_POSITIONS:
		var enemy := Hellspawn.new()
		enemy.position = Vector3(position_2d.x * CELL, position_2d.y, position_2d.z * CELL)
		enemy.setup(player, self)
		enemy.died.connect(_on_enemy_died)
		add_child(enemy)
		enemies_remaining += 1


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_material := ShaderMaterial.new()
	var vignette_shader := Shader.new()
	vignette_shader.code = "shader_type canvas_item; void fragment(){ vec2 p=UV*2.0-1.0; float v=smoothstep(1.2,0.35,length(p*vec2(0.82,1.0))); COLOR=vec4(0.08,0.0,0.0,(1.0-v)*0.62); }"
	vignette_material.shader = vignette_shader
	vignette.material = vignette_material
	layer.add_child(vignette)

	var top_bar := ColorRect.new()
	top_bar.color = Color(0.045, 0.012, 0.008, 0.88)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 46
	layer.add_child(top_bar)

	var title := _label("GODOT // HELLSPACE", 19, Color("f0b16e"))
	title.position = Vector2(18, 10)
	top_bar.add_child(title)

	fps_label = _label("FPS 0", 17, Color("df613d"))
	fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fps_label.position = Vector2(-112, 12)
	top_bar.add_child(fps_label)

	var bottom_bar := ColorRect.new()
	bottom_bar.color = Color(0.045, 0.012, 0.008, 0.92)
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -58
	layer.add_child(bottom_bar)

	health_label = _label("HEALTH 100", 22, Color("ef5737"))
	health_label.position = Vector2(18, 15)
	bottom_bar.add_child(health_label)

	enemies_label = _label("DEMONS %d" % enemies_remaining, 22, Color("ef5737"))
	enemies_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	enemies_label.position = Vector2(-160, 15)
	bottom_bar.add_child(enemies_label)

	var crosshair := _label("+", 27, Color("f2e4cc"))
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-8, -18)
	layer.add_child(crosshair)

	capture_hint = _label("CLICK TO CAPTURE MOUSE", 18, Color("f0b16e"))
	capture_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capture_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	capture_hint.position = Vector2(-140, 62)
	capture_hint.size = Vector2(280, 30)
	layer.add_child(capture_hint)

	weapon = TextureRect.new()
	weapon.texture = weapon_idle
	weapon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	weapon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	weapon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon.anchor_left = 0.5
	weapon.anchor_right = 0.5
	weapon.anchor_top = 1.0
	weapon.anchor_bottom = 1.0
	weapon.offset_left = -190
	weapon.offset_right = 190
	weapon.offset_top = -300
	weapon.offset_bottom = 78
	layer.add_child(weapon)

	message_label = _label("", 42, Color("ffb36e"))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message_label.visible = false
	layer.add_child(message_label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		pitch = clampf(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.15, 1.15)
		camera.rotation.x = pitch
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_fire()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_SPACE:
			_fire()
		elif event.keycode == KEY_R and (health <= 0 or enemies_remaining <= 0):
			get_tree().reload_current_scene()


func _physics_process(delta: float) -> void:
	if health <= 0:
		player.velocity = Vector3.ZERO
		return

	var input_vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_vector.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input_vector.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_LEFT): player.rotate_y(1.8 * delta)
	if Input.is_key_pressed(KEY_RIGHT): player.rotate_y(-1.8 * delta)

	input_vector = input_vector.normalized()
	var forward := -player.global_transform.basis.z
	var right := player.global_transform.basis.x
	var movement := (right * input_vector.x + forward * input_vector.y) * PLAYER_SPEED
	player.velocity.x = movement.x
	player.velocity.z = movement.z
	if not player.is_on_floor():
		player.velocity.y -= 18.0 * delta
	else:
		player.velocity.y = -0.1
	player.move_and_slide()


func _process(delta: float) -> void:
	capture_hint.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	fps_frames += 1
	fps_elapsed += delta
	if fps_elapsed >= 0.5:
		fps_label.text = "FPS %d" % roundi(fps_frames / fps_elapsed)
		fps_elapsed = 0.0
		fps_frames = 0


func _fire() -> void:
	if not can_fire or health <= 0 or enemies_remaining <= 0:
		return
	can_fire = false
	weapon.texture = weapon_fire
	var original_top := weapon.offset_top
	var tween := create_tween()
	tween.tween_property(weapon, "offset_top", original_top - 24.0, 0.045)
	tween.tween_property(weapon, "offset_top", original_top, 0.09)

	var origin := camera.global_position
	var end := origin + -camera.global_transform.basis.z * 50.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [player.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result and result.collider.has_method("damage"):
		result.collider.damage()

	await get_tree().create_timer(0.11).timeout
	weapon.texture = weapon_idle
	await get_tree().create_timer(0.16).timeout
	can_fire = true


func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(health - amount, 0)
	health_label.text = "HEALTH %d" % health
	if health <= 0:
		message_label.text = "YOU DIED\nPRESS R TO RESTART"
		message_label.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_enemy_died(_enemy: Hellspawn) -> void:
	enemies_remaining -= 1
	enemies_label.text = "DEMONS %d" % enemies_remaining
	if enemies_remaining <= 0:
		message_label.text = "HELLSPACE CLEARED\nPRESS R TO RESTART"
		message_label.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
