extends Node3D

const G: float = 6.674e-11

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var bodies = get_tree().get_nodes_in_group("bodies")
	
	for i in range(bodies.size()):
		for j in range(i+1, bodies.size()):
			apply_gravity(bodies[i], bodies[j], delta)
	

func apply_gravity(a, b, delta: float) -> void:
	var direction = b.position - a.position
	var distance_sq = direction.length_squared()
	var force_magnitude = G * a.mass * b.mass / distance_sq
	var force = direction.normalized() * force_magnitude
	
	a.velocity += (force / a.mass) * delta
	b.velocity -= (force / b.mass) * delta
