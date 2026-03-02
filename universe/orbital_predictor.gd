@tool
extends Node3D

@export var reference_body: MeshInstance3D
@export var show_path: bool

var G: float = 1000.0
var prediction_steps: int = 500
var prediction_step_size: float = 1.0

var _prediction_body_paths: Dictionary = {}

func apply_shadow_gravity(bodies: Array, positions: Dictionary, velocities: Dictionary) -> void:
	for i in range(bodies.size()):
		for j in range(i + 1, bodies.size()):
			var a = bodies[i]
			var b = bodies[j]
			var direction = positions[b] - positions[a]
			var distance_sq = direction.length_squared()
			var force_magnitude = G * a.mass * b.mass / distance_sq
			var force = direction.normalized() * force_magnitude

			velocities[a] += (force / a.mass) * prediction_step_size
			velocities[b] -= (force / b.mass) * prediction_step_size

func draw_predictions(bodies: Array) -> void:
	if show_path == false:
		for entry in _prediction_body_paths.values():
			if entry is Dictionary and is_instance_valid(entry.get("instance")):
				entry["instance"].visible = false
		return
	if bodies.is_empty():
		return

	var positions: Dictionary = {}
	var velocities: Dictionary = {}
	for body in bodies:
		positions[body] = body.position
		velocities[body] = body.velocity

	for body in bodies:
		var entry = _prediction_body_paths.get(body)
		if not (entry is Dictionary) \
			or not is_instance_valid(entry.get("instance")) \
			or not entry["instance"].is_inside_tree():
			var mesh = ImmediateMesh.new()
			var instance = MeshInstance3D.new()
			instance.mesh = mesh
			var mat = StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color.CYAN
			instance.material_override = mat
			add_child(instance)
			instance.owner = get_tree().edited_scene_root
			_prediction_body_paths[body] = {"mesh": mesh, "instance": instance}

	var vertexes: Dictionary = {}
	for body in bodies:
		vertexes[body] = [positions[body]]

	for _step in range(prediction_steps):
		apply_shadow_gravity(bodies, positions, velocities)
		for body in bodies:
			positions[body] += velocities[body] * prediction_step_size
			vertexes[body].append(positions[body])

	for body in bodies:
		var mesh = _prediction_body_paths[body]["mesh"]
		_prediction_body_paths[body]["instance"].visible = true
		mesh.clear_surfaces()
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for i in range(vertexes[body].size()):
			var point = vertexes[body][i]
			if reference_body and vertexes.has(reference_body):
				point = point - vertexes[reference_body][i] + reference_body.position
			mesh.surface_add_vertex(point)
		mesh.surface_end()
