extends CharacterBody3D

## Starting movement speed in world units per second.  Scroll wheel adjusts this at runtime.
@export var move_speed: float = 100000.0
## Scroll-wheel multiplier per tick — mirrors the Godot editor feel (1.3 ≈ 30 % per notch).
@export var scroll_speed_factor: float = 1.3
## Minimum and maximum speed the scroll wheel can reach.
@export var min_speed: float = 100.0
@export var max_speed: float = 100_000_000.0
## Mouse-look sensitivity.  Lower = slower, higher = faster.
@export var mouse_sensitivity: float = 0.003
## Camera offset in the player's local space.
## Vector3.ZERO gives first-person; e.g. Vector3(0, 2, 8) for a third-person feel.
@export var camera_offset: Vector3 = Vector3.ZERO
## Toggle gravity on/off.
@export var gravity_enabled: bool = true

# Accumulated pitch so we can clamp it independently of yaw.
var _pitch: float = 0.0
var _yaw: float = 0.0
var _camera: Camera3D = null
# Velocity accumulated from gravitational pulls.
var _gravity_velocity: Vector3 = Vector3.ZERO
# The "up" direction relative to the nearest planet.
var _gravity_up: Vector3 = Vector3.UP


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_camera = get_viewport().get_camera_3d()


func _unhandled_input(event: InputEvent) -> void:
	# Escape toggles mouse capture so you can click editor controls.
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		var captured := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(
			Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED
		)
		return

	# Scroll wheel adjusts speed multiplicatively, just like the Godot editor.
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			move_speed = clamp(move_speed * scroll_speed_factor, min_speed, max_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			move_speed = clamp(move_speed / scroll_speed_factor, min_speed, max_speed)

	# Mouse-look — only when the cursor is captured.
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, -PI * 0.5, PI * 0.5)


func _process(delta: float) -> void:
	# --- Update up direction from nearest body ---
	var nearest := _get_nearest_body()
	if is_instance_valid(nearest):
		var to_player := global_position - nearest.global_position
		if to_player.length_squared() > 0.01:
			_gravity_up = to_player.normalized()
	global_transform.basis = _get_orientation()

	# --- Build movement direction in the player's local space ---
	var direction := Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		direction -= transform.basis.z      # forward  (local -Z)
	if Input.is_key_pressed(KEY_S):
		direction += transform.basis.z      # backward (local +Z)
	if Input.is_key_pressed(KEY_A):
		direction -= transform.basis.x      # strafe left
	if Input.is_key_pressed(KEY_D):
		direction += transform.basis.x      # strafe right
	if Input.is_key_pressed(KEY_SHIFT):
		direction += transform.basis.y      # up
	if Input.is_key_pressed(KEY_CTRL):
		direction -= transform.basis.y      # down

	if direction.length_squared() > 0.0:
		direction = direction.normalized()

	if gravity_enabled:
		_apply_gravity(delta)

	var motion := direction * move_speed * delta + _gravity_velocity * delta
	var collision := move_and_collide(motion)
	if collision:
		# Remove the velocity component pushing into the surface so we don't
		# keep accelerating through the planet.
		_gravity_velocity = _gravity_velocity.slide(collision.get_normal())

	# --- Keep the camera locked to the player ---
	if is_instance_valid(_camera):
		_camera.global_position = global_position + global_transform.basis * camera_offset
		_camera.global_rotation = global_rotation
		
@export var gravity_radius: float = 20000.0

func _get_nearest_body() -> Node3D:
	var bodies: Array = []
	_collect_bodies(get_tree().root, bodies)
	var nearest: Node3D = null
	var nearest_dist_sq: float = INF
	for body in bodies:
		var d: float = (body.global_position - global_position).length_squared()
		if d < nearest_dist_sq:
			nearest_dist_sq = d
			nearest = body
	return nearest


func _get_orientation() -> Basis:
	var up := _gravity_up
	# Pick a reference vector that isn't parallel to up.
	var ref := Vector3.FORWARD
	if abs(up.dot(Vector3.FORWARD)) > 0.95:
		ref = Vector3.RIGHT
	# North = forward direction in the horizontal plane.
	var north := (ref - ref.dot(up) * up).normalized()
	var east := north.cross(up).normalized()
	# Apply yaw around up, then pitch around the resulting right axis.
	var yaw_quat := Quaternion(up, _yaw)
	var facing := yaw_quat * north
	var right := yaw_quat * east
	var pitch_quat := Quaternion(right, -_pitch)
	var final_forward := pitch_quat * facing
	var final_up := pitch_quat * up
	return Basis(right, final_up, -final_forward).orthonormalized()


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
