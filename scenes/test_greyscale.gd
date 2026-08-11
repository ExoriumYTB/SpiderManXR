extends Node3D

@onready var left_controller: XRController3D = $".."

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if left_controller.is_button_pressed("ax_button"):
		RenderingServer.global_shader_parameter_set("global_saturation", 0.1)
	elif left_controller.is_button_pressed("by_button"):
		RenderingServer.global_shader_parameter_set("global_saturation", 1.0)
