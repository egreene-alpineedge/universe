@tool
extends Node3D

@export var G: float = 1000.0

# Orbital Path
@export var prediction_steps: int = 500
@export var prediction_step_size: float = 1.0

func _process(delta: float) -> void:
	
	# Orbital Path
	if Engine.is_editor_hint():
		var predictor = get_node_or_null("OrbitalPredictor")
		if predictor:
			predictor.G = G
			predictor.prediction_steps = prediction_steps
			predictor.prediction_step_size = prediction_step_size
			predictor.draw_predictions(get_tree().get_nodes_in_group("bodies"))
		return

	# Apply gravity to bodies
	var bodies = get_tree().get_nodes_in_group("bodies")
	apply_gravity(bodies, delta)

func apply_gravity(bodies: Array, delta: float) -> void:
	for i in range(bodies.size()):
		for j in range(i + 1, bodies.size()):
			var a = bodies[i]
			var b = bodies[j]
			var direction = b.position - a.position
			var distance_sq = direction.length_squared()
			var force_magnitude = G * a.mass * b.mass / distance_sq
			var force = direction.normalized() * force_magnitude

			a.velocity += (force / a.mass) * delta
			b.velocity -= (force / b.mass) * delta
