@tool
extends Node3D

## Shows the exact circular orbital path of every celestial_body2 that is a
## sibling (or descendant) of this node.  Because celestial_body2 uses a known
## parametric formula (origin + Vector3(cos(t)*radius, 0, sin(t)*radius))
## the full orbit can be drawn exactly — no physics simulation required.
## Supports hierarchical orbits: if a body has a center_body node reference
## (e.g. Moon → Earth), the ring is drawn around that body's current position.

@export var show_path: bool = true
## Number of line segments used to approximate each circle.
## Higher values look smoother; 128 is more than enough for most orbits.
@export var path_segments: int = 128
@export var path_color: Color = Color.CYAN

# Maps each body node → { "mesh": ImmediateMesh, "instance": MeshInstance3D }
var _body_path_instances: Dictionary = {}


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		# Bodies in this scene are never added to the "bodies" group while in
		# the editor, so we collect them by walking the parent's children and
		# checking for the properties celestial_body2.gd exposes instead.
		var candidates: Array = []
		_collect_orbital_bodies(get_parent(), candidates)
		draw_predictions(candidates)


## Recursively gathers nodes that look like celestial_body2 instances.
func _collect_orbital_bodies(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child == self:
			continue
		if child.get("orbit_length_in_seconds") != null:
			result.append(child)
		# Recurse so moons nested under planets are found too.
		_collect_orbital_bodies(child, result)


func draw_predictions(bodies: Array) -> void:
	# ------------------------------------------------------------------
	# Hide all paths when show_path is off and return early.
	# ------------------------------------------------------------------
	if not show_path:
		for entry in _body_path_instances.values():
			if entry is Dictionary and is_instance_valid(entry.get("instance")):
				entry["instance"].visible = false
		return

	if bodies.is_empty():
		return

	# ------------------------------------------------------------------
	# Process each body that belongs to the celestial_body2 orbit model.
	# We detect these by checking for the properties that script exposes.
	# ------------------------------------------------------------------
	for body in bodies:
		# Skip bodies that don't use the parametric orbit model.
		# Use .get() so we never crash on nodes that lack these properties.
		var orbit_len = body.get("orbit_length_in_seconds")
		if orbit_len == null or float(orbit_len) == 0.0:
			continue
		var body_radius = body.get("radius")
		if body_radius == null or float(body_radius) == 0.0:
			continue
		# Resolve orbit centre: prefer live center_body position, fall back to
		# the static center_position vector (used by planets orbiting the origin).
		var center_body = body.get("center_body")
		var origin: Vector3
		if center_body != null and is_instance_valid(center_body):
			origin = center_body.position
		else:
			var cp = body.get("center_position")
			if cp == null:
				continue
			origin = cp

		# --------------------------------------------------------------
		# Lazily create a mesh + material for this body if needed.
		# --------------------------------------------------------------
		var entry = _body_path_instances.get(body)
		if not (entry is Dictionary) \
				or not is_instance_valid(entry.get("instance")) \
				or not entry["instance"].is_inside_tree():

			var mesh := ImmediateMesh.new()
			var instance := MeshInstance3D.new()
			instance.mesh = mesh

			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = path_color
			instance.material_override = mat

			add_child(instance)
			instance.owner = get_tree().edited_scene_root
			_body_path_instances[body] = {"mesh": mesh, "instance": instance}

		# --------------------------------------------------------------
		# Draw the exact circular orbit.
		# Formula mirrors celestial_body2._process exactly, including tilt.
		# We close the loop by including segment 0 again at the end (i == path_segments).
		# --------------------------------------------------------------
		var mesh: ImmediateMesh = _body_path_instances[body]["mesh"]
		_body_path_instances[body]["instance"].visible = true
		mesh.clear_surfaces()
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

		var r := float(body_radius)
		var raw_tilt = body.get("orbit_tilt")
		var tilt_rad := deg_to_rad(float(raw_tilt) if raw_tilt != null else 0.0)

		for i in range(path_segments + 1):          # +1 closes the loop
			var t := float(i) / float(path_segments) * TAU
			var offset := Vector3(cos(t) * r, 0.0, sin(t) * r)
			if tilt_rad != 0.0:
				offset = offset.rotated(Vector3.FORWARD, tilt_rad)
			mesh.surface_add_vertex(origin + offset)

		mesh.surface_end()
