extends ProgressBar

@export_category("Health")
@export var health_component : HealthComponent

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not health_component:
		push_warning("No health component were given to the health bar, trying to find one with group health_component")
		
		if get_tree().get_first_node_in_group("health_component"):
			health_component = get_tree().get_first_node_in_group("health_component")
			push_warning("Used the group health component to find the health component")
			
		else:
			push_error("No health component found in any ways for the health bar")
			return
	
	min_value = 0.0
	max_value = health_component.max_health
	value = health_component.current_health
			


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	value = health_component.current_health
