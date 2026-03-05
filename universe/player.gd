extends CharacterBody3D

### Starting movement speed in world units per second.  Scroll wheel adjusts this at runtime.
#@export var move_speed: float = 1000.0
### Scroll-wheel multiplier per tick — mirrors the Godot editor feel (1.3 ≈ 30 % per notch).
#@export var scroll_speed_factor: float = 1.3
### Minimum and maximum speed the scroll wheel can reach.
#@export var min_speed: float = 100.0
#@export var max_speed: float = 100000.0
### Mouse-look sensitivity.  Lower = slower, higher = faster.
@export var mouse_sensitivity: float = 0.003
### Camera offset in the player's local space.
### Vector3.ZERO gives first-person; e.g. Vector3(0, 2, 8) for a third-person feel.
@export var camera_offset: Vector3 = Vector3.ZERO
### Toggle gravity on/off.
@export var gravity_enabled: bool = true
@export var gravity_radius: float = 20000.0

@export var mass: float = 1
@export var acceleration: float = 500.0
@export var damping: float = 0.0  # 0 = no drag (space), 0.99 = heavy drag
var player_velocity: Vector3 = Vector3.ZERO

## Accumulated pitch so we can clamp it independently of yaw.
var _pitch: float = 0.0
var _camera: Camera3D = null
## Velocity accumulated from gravitational pulls.
var _gravity_velocity: Vector3 = Vector3.ZERO
var _velocity_label: Label = null
var _selected_body: Node3D = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_camera = get_viewport().get_camera_3d()

	var canvas := CanvasLayer.new()
	add_child(canvas)
	_velocity_label = Label.new()
	_velocity_label.position = Vector2(10, 10)
	_velocity_label.add_theme_font_size_override("font_size", 16)
	canvas.add_child(_velocity_label)


func _unhandled_input(event: InputEvent) -> void:
	# Escape toggles mouse capture so you can click editor controls.
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		var captured := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(
			Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED
		)
		return

	# Scroll wheel adjusts speed multiplicatively, just like the Godot editor.
	#if event is InputEventMouseButton:
		#if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			#move_speed = clamp(move_speed * scroll_speed_factor, min_speed, max_speed)
		#elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			#move_speed = clamp(move_speed / scroll_speed_factor, min_speed, max_speed)

	# Left click — try to select a planet (only when cursor is visible).
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed \
			and Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		_try_select_body()

	# Mouse-look — only when the cursor is captured.
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, -PI * 0.5, PI * 0.5)
		rotation.x = _pitch


func _physics_process(delta: float) -> void:
	# --- Accumulate thrust into player_velocity ---
	var thrust := Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		thrust -= transform.basis.z      # forward  (local -Z)
	if Input.is_key_pressed(KEY_S):
		thrust += transform.basis.z      # backward (local +Z)
	if Input.is_key_pressed(KEY_A):
		thrust -= transform.basis.x      # strafe left
	if Input.is_key_pressed(KEY_D):
		thrust += transform.basis.x      # strafe right
	if Input.is_key_pressed(KEY_SHIFT):
		thrust += transform.basis.y      # up
	if Input.is_key_pressed(KEY_CTRL):
		thrust -= transform.basis.y      # down

	if thrust.length_squared() > 0.0:
		thrust = thrust.normalized()

	player_velocity += thrust * acceleration * delta
	player_velocity = player_velocity.lerp(Vector3.ZERO, damping * delta)

	# --- Velocity match selected body (hold Space) ---
	if Input.is_key_pressed(KEY_SPACE) and is_instance_valid(_selected_body):
		var target: Vector3 = _selected_body.velocity
		var diff := target - player_velocity
		if diff.length() > 1.0:
			player_velocity += diff.normalized() * acceleration * delta
		else:
			player_velocity = target

	if gravity_enabled:
		_apply_gravity(delta)

	var motion := player_velocity * delta + _gravity_velocity * delta
	var collision := move_and_collide(motion)
	if collision:
		## Remove the velocity component pushing into the surface so we don't
		## keep accelerating through the planet.
		_gravity_velocity = _gravity_velocity.slide(collision.get_normal())

	# --- HUD ---
	var hud := "Velocity: (%.1f, %.1f, %.1f)\n" % [player_velocity.x, player_velocity.y, player_velocity.z]
	if is_instance_valid(_selected_body):
		var bv: Vector3 = _selected_body.velocity
		var rel: Vector3 = player_velocity - bv
		hud += "\n[%s]\nVelocity: (%.1f, %.1f, %.1f)\nSpeed: %.1f m/s\nRelative speed: %.1f m/s  %s" % [
			_selected_body.name,
			bv.x, bv.y, bv.z,
			bv.length(),
			rel.length(),
			"[MATCHING]" if Input.is_key_pressed(KEY_SPACE) else "[SPACE to match]"
		]
	else:
		hud += "\n[Click a planet to inspect]"
	_velocity_label.text = hud

	# --- Keep the camera locked to the player ---
	if is_instance_valid(_camera):
		_camera.global_position = global_position + global_transform.basis * camera_offset
		_camera.global_rotation = global_rotation

func _try_select_body() -> void:
	if not is_instance_valid(_camera):
		return
	var space := get_world_3d().direct_space_state
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := _camera.project_ray_origin(mouse_pos)
	var ray_end := ray_origin + _camera.project_ray_normal(mouse_pos) * 1_000_000_000.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self]
	var result := space.intersect_ray(query)
	if result and result.get("collider") != null:
		var collider = result["collider"]
		if collider.get("velocity") != null:
			_selected_body = collider
	else:
		_selected_body = null


func _apply_gravity(delta: float) -> void:
	var bodies: Array = []
	_collect_bodies(get_tree().root, bodies)
	for body in bodies:
		var dir: Vector3 = body.global_position - global_position
		var dist_sq: float = dir.length_squared()
		if dist_sq < 1.0:
			continue
		if dist_sq > gravity_radius * gravity_radius:
			continue
		var accel: float = float(body.get("G")) * float(body.get("mass")) / dist_sq
		_gravity_velocity += dir.normalized() * accel * delta


func _collect_bodies(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child.get("mass") != null and child.get("G") != null:
			result.append(child)
		_collect_bodies(child, result)
