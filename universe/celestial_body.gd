@tool
extends AnimatableBody3D

@export var mass: float = 1.0e24
@export var color: Color = Color.CYAN
@export var velocity: Vector3 = Vector3.ZERO

@export var show_child_orbits: bool = true
@export var G: float = 1000.0
@export var prediction_steps: int = 500
@export var prediction_step_size: float = 1.0

# Keyed by child instance ID → { mesh, instance }
var _orbit_lines: Dictionary = {}


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if show_child_orbits:
			_draw_children_orbits()
		return

	_apply_gravity_to_children(delta)
	position += velocity * delta


# ── Shared gravity step ───────────────────────────────────────────────────────
# Updates velocities in-place. positions and velocities are Dictionaries keyed
# by child node, holding Vector3 values. step_size is the time increment.

func _gravity_step(children: Array, positions: Dictionary, velocities: Dictionary, step_size: float) -> void:
	# Parent (self) pulls every child — parent never moves
	for child in children:
		var pos: Vector3 = positions[child] as Vector3
		var dist_sq: float = pos.length_squared()
		if dist_sq < 1.0:
			continue
		var accel: float = G * mass / dist_sq
		velocities[child] = (velocities[child] as Vector3) + -pos.normalized() * accel * step_size


# ── Runtime gravity ───────────────────────────────────────────────────────────

func _apply_gravity_to_children(delta: float) -> void:
	var children: Array = get_children().filter(
		func(c): return c.get("velocity") != null and c.get("mass") != null
	)
	if children.is_empty():
		return

	var positions: Dictionary = {}
	var velocities: Dictionary = {}
	for child in children:
		positions[child] = child.position as Vector3
		velocities[child] = child.velocity as Vector3

	_gravity_step(children, positions, velocities, delta)

	# Write updated velocities back to the nodes
	for child in children:
		child.velocity = velocities[child]


# ── Editor prediction ─────────────────────────────────────────────────────────

func _draw_children_orbits() -> void:
	var children: Array = get_children().filter(
		func(c): return c.get("velocity") != null and c.get("mass") != null
	)
	if children.is_empty():
		return

	var positions: Dictionary = {}
	var velocities: Dictionary = {}
	var vertexes: Dictionary = {}
	for child in children:
		positions[child] = child.position as Vector3
		velocities[child] = child.velocity as Vector3
		vertexes[child] = [child.position as Vector3]

	for child in children:
		_ensure_line(child)

	for _step in range(prediction_steps):
		_gravity_step(children, positions, velocities, prediction_step_size)
		for child in children:
			positions[child] = (positions[child] as Vector3) + (velocities[child] as Vector3) * prediction_step_size
			vertexes[child].append(positions[child])

	for child in children:
		var line_mesh: ImmediateMesh = _orbit_lines[child.get_instance_id()]["mesh"]
		line_mesh.clear_surfaces()
		line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for point: Vector3 in vertexes[child]:
			line_mesh.surface_add_vertex(point)
		line_mesh.surface_end()


func _ensure_line(child: Node3D) -> void:
	var id := child.get_instance_id()
	if _orbit_lines.has(id) and is_instance_valid(_orbit_lines[id].get("instance")):
		return

	var mesh := ImmediateMesh.new()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var child_color = child.get("color")
	mat.albedo_color = child_color if child_color != null else Color.WHITE
	instance.material_override = mat
	add_child(instance)
	instance.owner = get_tree().edited_scene_root
	_orbit_lines[id] = {"mesh": mesh, "instance": instance}
