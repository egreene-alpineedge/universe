@tool
extends Node3D

const BODY_SCRIPT = preload("res://celestial_body2.gd")

@export var body_size_scale: float = 1
@export var body_distance_scale: float = 1

@export_tool_button("Spawn Bodies from CSV") var _btn = func(): _spawn_bodies("res://bodies.csv")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _spawn_bodies(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Could not open: " + path)
		return

	var headers = file.get_csv_line()

	while not file.eof_reached():
		var values = file.get_csv_line()
		if values.size() < headers.size():
			continue
		var row = {}
		for i in range(headers.size()):
			row[headers[i].strip_edges()] = values[i].strip_edges()
		_spawn_body(row)
		

func _spawn_body(data: Dictionary) -> void:
	var body = MeshInstance3D.new()
	body.set_script(BODY_SCRIPT)
	var sphere = SphereMesh.new()
	sphere.radius = float(data["Radius"])
	sphere.height = float(data["Radius"]) * 2.0
	body.mesh = sphere
	body.name = data["Name"]
	body.position = Vector3(
		float(data["x"]),
		float(data["y"]),
		float(data["z"])
	)
	body.add_to_group("bodies")
	add_child(body)
	body.owner = get_tree().edited_scene_root  # saves to scene!
