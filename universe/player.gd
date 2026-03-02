extends MeshInstance3D

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

# Accumulated pitch so we can clamp it independently of yaw.
var _pitch: float = 0.0
var _camera: Camera3D = null


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
		rotation.y -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, -PI * 0.5, PI * 0.5)
		rotation.x = _pitch


func _process(delta: float) -> void:
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

	global_position += direction * move_speed * delta

	# --- Keep the camera locked to the player ---
	if is_instance_valid(_camera):
		_camera.global_position = global_position + global_transform.basis * camera_offset
		_camera.global_rotation = global_rotation
