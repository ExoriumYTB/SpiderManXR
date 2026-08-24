class_name SimpleEnemy
extends Enemy

@export_category("Enemy Vars")
@export var follow_speed: float = 3.0
@export var stop_follow_distance := 10

@export_category("Debug")
@export var debug := false

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var state_chart: StateChart = $StateChart

signal on_death

var target: Node3D

func _ready() -> void:
	super._ready()
	
	# Find player
	target = get_tree().get_first_node_in_group("player")
	
	# Connect signals
	navigation_agent_3d.velocity_computed.connect(_on_velocity_computed)
	
	#Debug
	if debug:
		print(target)
		navigation_agent_3d.debug_enabled = true
	
func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	move_and_slide()
	
func on_triggered() -> void:
	state_chart.send_event("toFollow")
	
func _on_died() -> void:
	on_death.emit()
	queue_free()

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z


func _on_follow_state_physics_processing(delta: float) -> void:
	if not target:
		return
	
	if target.global_position.distance_to(self.global_position) >= stop_follow_distance:
		if debug:
			print("To far to follow player")
		return
	
	# Set target position for navigation
	navigation_agent_3d.target_position = target.global_position
	
	# Check if navigation is finished
	if navigation_agent_3d.is_navigation_finished():
		navigation_agent_3d.velocity = Vector3.ZERO
		return
	
	# Get next position in path
	var next_pos = navigation_agent_3d.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	
	# Set desired velocity (NavAgent handle avoidance)
	navigation_agent_3d.velocity = direction * follow_speed
	
	# Rotate to face movement direction
	if direction.length() > 0.01:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 5.0 * delta)

func _on_detection_area_body_entered(body: Node3D) -> void:
	print(body)
	if body.is_in_group("player"):
		on_triggered()
