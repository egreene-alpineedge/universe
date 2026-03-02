extends MeshInstance3D

## Node to orbit around (e.g. Earth for the Moon). When set, center_position
## is ignored and the body always orbits the live position of center_body.
@export var center_body: Node3D
## Fallback fixed point used when center_body is not assigned (e.g. the Sun
## sits at the origin, so planets can leave center_body empty).
@export var center_position : Vector3
@export var radius := 0
@export var angle := 0.0
@export var orbit_length_in_seconds := 0.0

@export var orbit_tilt: float = 0.0

func _ready() -> void:
	pass


func _process(delta: float) -> void:
	if orbit_length_in_seconds == 0.0:
		return

	angle += TAU / orbit_length_in_seconds * delta

	# Use the live position of center_body if one is assigned,
	# otherwise fall back to the static center_position vector.
	var origin := center_body.position if is_instance_valid(center_body) else center_position

	var offset = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
	# rotate the flat orbit plane around the Z axis by the tilt angle
	offset = offset.rotated(Vector3.FORWARD, deg_to_rad(orbit_tilt))
	position = origin + offset
