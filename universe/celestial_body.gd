extends MeshInstance3D

@export var mass: float = 1.0e24
@export var velocity: Vector3 = Vector3.ZERO

func _process(delta: float) -> void:
	position += velocity * delta
