class_name HealthComponent extends Node

## Reusable health component

signal health_changed(new_health: float, max_health: float)
signal damage_taken(amount: float, source: Node3D)
signal died()

@export_category("Health")
@export var max_health: float = 100.0
@export var start_at_max := true

@export_category("Debug")
@export var debug: bool = false

var current_health : float
var is_alive := true

func _ready() -> void:
	if start_at_max:
		current_health = max_health

func take_damage(amount: float, source: Node3D = null) -> void:
	if not is_alive:
		return
	
	# Max are used to clamp the damage/health to a min of 0.0
	var actual_damage = max(0.0, amount)
	current_health = max(0.0, current_health - actual_damage)
	
	damage_taken.emit(actual_damage, source)
	health_changed.emit(current_health, max_health)
	
	if debug:
		print(get_parent().name, " took: ", actual_damage, " damage. Health: ",
				current_health, "/", max_health)
	
	if current_health <= 0.0:
		_handle_death()

func heal(amount: float) -> void:
	if not is_alive:
		return
	
	var actual_heal = max(0.0, amount)
	current_health = min(max_health, current_health + actual_heal)
	
	health_changed.emit(current_health, max_health)
	
func _handle_death() -> void:
	if not is_alive:
		return
	
	is_alive = false
	current_health = 0.0
	died.emit()
	
	if debug:
		print(get_parent().name, " died!")
