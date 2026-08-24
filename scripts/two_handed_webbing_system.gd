@tool
@icon("res://addons/godot-xr-tools/editor/icons/movement_provider.svg")
class_name TwoHandedWebbingSystem
extends XRToolsMovementProvider


## XR Tools Movement Provider for Webbing Movement like Spiderman
##
## This script provide simple web based movement - "spiderman" style
## where the player flings a web to the target and swings on it.
## This script works with the [XRToolsPlayerBody] attached to the players
## [XROrigin3D].


## Emitted when web starts
signal web_started(hand: Hand)

## Emitted when web finishes
signal web_finished(hand: Hand)

enum Hand {
	LEFT,
	RIGHT
}

## Default web collision mask of 1-5 (world)
const DEFAULT_COLLISION_MASK := 0b0000_0000_0000_0000_0000_0000_0001_1111

## Default web enable mask of 5:web-target
const DEFAULT_ENABLE_MASK := 0b0000_0000_0000_0000_0000_0000_0001_0000

## Order in which movement is processed
@export var order: int = 20

## web length - use to adjust maximum distance for possible web hooking.
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var web_length := 15.0

## web collision mask
@export_flags_3d_physics var web_collision_mask := DEFAULT_COLLISION_MASK:
	set = _set_web_collision_mask

## web enable mask
@export_flags_3d_physics var web_enable_mask := DEFAULT_ENABLE_MASK

## Impulse speed applied to the player on first web
@export_custom(PROPERTY_HINT_NONE, "suffix:m/s") var impulse_speed := 10.0

## Winch speed applied to the player while the web is held
@export_custom(PROPERTY_HINT_NONE, "suffix:m/s") var winch_speed := 2.0

## The strength multiplier to the pull
@export var pull_strength := 0.05
## The minimum pulling distance to be considered valid (in meters)
@export var min_pull_distance : float = 0.10

## Probably need to add export variables for line size, maybe line material at
## some point so dev does not need to make children editable to do this.
## For now, right click on web node and make children editable to edit these
## facets.
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var rope_width := 0.02

## Air friction while webbing
@export var friction := 0.1

## Input action that triggers webbing movement. Be sure this button does not
## conflict with other functions.
@export var web_shoot_action := "trigger_click"
@export var web_lock_action := "grip_click"

## Class that handle all variables for hands
class WebHand:
	var side: Hand #what hand is this WebHand
	
	# Controller related ref
	var controller: XRController3D #The controller
	
	# Web related ref
	var root: Node3D
	var web_raycast: RayCast3D #The web raycast ref
	var web_target: MeshInstance3D #The web target ref
	var line_helper: Node3D #The line helper ref
	var line: CSGCylinder3D #The line ref
	
	# State ref
	var active := false #Is this hand active
	var web_shoot_button := false #Is the button pressed on the controller
	var web_lock_button := false #Is the putton for pulling the player is active
	
	# Hook related variables
	var hook_object: Node3D = null
	var hook_local := Vector3(0,0,0)
	var hook_point := Vector3(0,0,0)
	var locked_length := 0.0
	var can_set_lock_lenght := true #Utile pour savoir quand mettre à jour lock_length
	
	#Celocity and position related var,
	#used to calculate velocity and pulling force
	var previous_local_hand_position := Vector3.ZERO
	var hand_local_velocity := Vector3.ZERO
	var local_hand_position := Vector3.ZERO

var left_hand := WebHand.new()
var right_hand := WebHand.new()

func _enter_tree() -> void:
	left_hand.controller = XRHelpers.get_left_controller(self)
	right_hand.controller = XRHelpers.get_right_controller(self)

# Runs when node is added to scene
func _ready() -> void:
	# In Godot 4 we must now manually call our super class ready function
	super()
	
	# Skip if running in the editor
	if Engine.is_editor_hint():
		return
	
	_setup_hand(left_hand, Hand.LEFT)
	_setup_hand(right_hand, Hand.RIGHT)
	
	# Ensure web length is valid
	var min_hook_length := 1.5 * XRServer.world_scale
	if web_length < min_hook_length:
		web_length = min_hook_length


func _setup_hand(hand : WebHand, side: Hand):
	var sideName: String
	var sidePath: String
	
	match side:
		#LEFT HAND
		0:
			sideName = "Left"
			sidePath = "Left/"
		#RIGHT HAND
		1:
			sideName = "Right"
			sidePath = "Right/"
	
	# Setup side for hands
	hand.side = side
	
	# Line creation nodes
	hand.line_helper = get_node(sidePath+"LineHelper")
	hand.line = get_node(sidePath+"LineHelper/Line")
	
	# Get Raycast node
	hand.web_raycast = get_node(sidePath+"Web_RayCast")
	
	# Get web Target Node
	hand.web_target = get_node(sidePath+"Web_Target")
	
	#Define the root
	hand.root = get_node(sideName)
	
	# Set ray-cast
	hand.web_raycast.target_position = Vector3(0, 0, -web_length) * XRServer.world_scale
	hand.web_raycast.collision_mask = web_collision_mask

	# Deal with line
	hand.line.radius = rope_width
	hand.line.hide()
	
	# Reparent the root so it follow the hands
	hand.root.reparent(hand.controller, true)

# Update the webbing line and target
func _physics_process(_delta: float) -> void:
	# Skip if running in the editor
	if Engine.is_editor_hint():
		return
	
	_calculate_target_visibility(left_hand)
	_calculate_target_visibility(right_hand)
	
	_calculate_webbing_line(left_hand)
	_calculate_webbing_line(right_hand)
	
	_calculate_hand_local_velocity(left_hand, _delta)
	_calculate_hand_local_velocity(right_hand, _delta)

## If pointing web at target then show the target
func _calculate_target_visibility(hand : WebHand):
	
	if enabled and not hand.active and _is_raycast_valid(hand):
		hand.web_target.global_transform.origin = hand.web_raycast.get_collision_point()
		hand.web_target.global_transform = hand.web_target.global_transform.orthonormalized()
		hand.web_target.visible = true
	else:
		hand.web_target.visible = false

## If actively webbing then update and show the webbing line
func _calculate_webbing_line(hand : WebHand):
	if hand.active:
		var line_length := (hand.hook_point - hand.controller.global_transform.origin).length()
		hand.line_helper.look_at(hand.hook_point, Vector3.UP)
		hand.line.height = line_length
		hand.line.position.z = line_length / -2
		hand.line.visible = true
	else:
		hand.line.visible = false

func _calculate_hand_local_velocity(hand: WebHand, delta: float) -> void:
	var current = hand.local_hand_position
	hand.local_hand_position = hand.controller.global_position - XRHelpers.get_xr_origin(self).global_position
	hand.hand_local_velocity = (hand.local_hand_position - hand.previous_local_hand_position) / delta
	
	hand.previous_local_hand_position = current

func _exit_tree() -> void:
	left_hand.controller = null
	right_hand.controller = null


# Verifies the movement provider has a valid configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()

	# Check the controller node
	if not XRHelpers.get_left_controller(self) or not XRHelpers.get_right_controller(self):
		warnings.append("This node must be within an XROrigin3D")

	# Return warnings
	return warnings

## Adds support for [method is_xr_class] on XRTools classes
func is_xr_class(xr_name: String) -> bool:
	return xr_name == "TwoHandedWebbingSystem" or super(xr_name)


## Performs web movement
func physics_movement(
		delta: float,
		player_body: XRToolsPlayerBody,
		disabled: bool,
) -> bool:
	
	if not _can_use_web(disabled, left_hand) and not _can_use_web(disabled, right_hand):
		return false
	
	#var do_left_impulse = _update_hand(left_hand)
	#var do_right_impulse = _update_hand(right_hand)
	
	_update_hand(left_hand)
	_update_hand(right_hand)
	
	if not left_hand.active and not right_hand.active:
		return false

	# Apply gravity
	player_body.velocity += player_body.gravity * delta
	
	## Get web force and cache it
	#var web_force := Vector3.ZERO
	#
	#web_force += _get_web_force(left_hand, player_body.velocity, do_left_impulse)
	#web_force += _get_web_force(right_hand, player_body.velocity, do_right_impulse)
	
	# Get the pull force then cache it
	## Contain the force that pull the player
	var pull_force := Vector3.ZERO
	
	pull_force += _get_pull_force(left_hand)
	pull_force += _get_pull_force(right_hand)
	
	# Get the lock velocity then cache it
	## Contain the velocity needed to lock the length of the web
	var lock_force := Vector3.ZERO
	
	lock_force += _lock_web_length(left_hand, player_body.velocity)
	lock_force += _lock_web_length(right_hand, player_body.velocity)
	
	# Apply the web force
	#player_body.velocity += web_force
	
	# Apply the pull force
	player_body.velocity += pull_force
	
	# Apply the lock force
	player_body.velocity += lock_force
	
	# Scale down velocity
	player_body.velocity *= 1.0 - friction * delta

	# Perform exclusive movement as we have dealt with gravity
	player_body.velocity = player_body.move_player(player_body.velocity)
	
	return true

func _can_use_web(disabled: bool, hand: WebHand) -> bool:
	# Disable if requested
	if disabled or not enabled:
		_set_webbing(hand, false)
		return false
	
	return true

## update the hand, if the button is pressed then update the web line
func _update_hand(hand: WebHand) -> bool:
	# Update web button
	var old_web_shoot_button := hand.web_shoot_button
	hand.web_shoot_button = hand.controller.is_button_pressed(web_shoot_action)
	
	# Enable/disable webbing
	var do_impulse := false
	if hand.active and not hand.web_shoot_button:
		_set_webbing(hand, false)
	elif hand.web_shoot_button and not old_web_shoot_button and _is_raycast_valid(hand):
		hand.hook_object = hand.web_raycast.get_collider()
		hand.hook_point = hand.web_raycast.get_collision_point()
		hand.hook_local = hand.hook_point * hand.hook_object.global_transform
		
		do_impulse = true
		_set_webbing(hand, true)
	
	return do_impulse

## Return a Vector3 that is the force that need to be applied to the player
#func _get_web_force(hand: WebHand, player_velocity: Vector3, do_impulse: bool) -> Vector3:
#	if not hand.active or not hand.web_pull_button:
#		return Vector3.ZERO
#	
#	# Get hook direction
#	hand.hook_point = hand.hook_object.global_transform * hand.hook_local
#	var hook_vector := hand.hook_point - hand.controller.global_transform.origin
#	var hook_length := hook_vector.length()
#	var hook_direction := hook_vector / hook_length
#	
#	# Select the web speed
#	var speed := impulse_speed if do_impulse else winch_speed
#	if hook_length < 1.0:
#		speed = 0.0
#	
#	# Ensure velocity is at least winch_speed towards hook
#	var vdot: float = player_velocity.dot(hook_direction)
#	if vdot < speed:
#		return hook_direction * (speed - vdot)
#	
#	return Vector3.ZERO

## Return a Vector3 that is the velocity needed to remove the radial force of the player and lock the lenght of the web
func _lock_web_length(hand: WebHand, player_velocity: Vector3) -> Vector3:
	#if not hand.active or not hand.web_lock_button:
	#	print(" hand not active or web_lock_button not pushed")
	#	return Vector3.ZERO
	
	var current_length := hand.controller.global_position.distance_to(hand.hook_point)
	
	var old_web_lock_button := hand.web_lock_button
	hand.web_lock_button = hand.controller.is_button_pressed(web_lock_action)
	
	if hand.web_lock_button and not old_web_lock_button and hand.can_set_lock_lenght:
		hand.locked_length = current_length
		hand.can_set_lock_lenght = false
	elif not hand.web_lock_button and old_web_lock_button and not hand.can_set_lock_lenght:
		hand.locked_length = 0.0
		hand.can_set_lock_lenght = true
	
	if hand.locked_length > 0:
		var hook_direction := (hand.hook_point - hand.controller.global_position).normalized()
		var overflow := current_length - hand.locked_length
		var radial_speed := player_velocity.dot(hook_direction)
		
		# Si l'overflow est négatif ne rien faire.
		# Cela signifie que la corde/web n'est pas tendu et donc
		# Que l'on peut la détendre
		if overflow < 0:
			return Vector3.ZERO
		
		# Après avoir calculé radial speed, si c'est plus grand que zéro,
		# c'est que l'on séloigne
		if radial_speed > 0:
			return Vector3.ZERO
		
		# On negate radial_speed pour obtenir une vrai velocity 
		# qui nous tire et non qui nous pousse
		var velocity := hook_direction * -radial_speed
		
		return velocity
	
	return Vector3.ZERO

func _get_pull_force(hand: WebHand) -> Vector3:
	
	var hook_direction := (hand.hook_point - hand.controller.global_position).normalized()
	var pull_speed = -hand.hand_local_velocity.dot(hook_direction)
	
	if pull_speed <= 0:
		return Vector3.ZERO
	
	var impulse = hook_direction * pull_speed * pull_strength
	
	return impulse

# Tests if the raycast is striking a valid target
func _is_raycast_valid(hand : WebHand) -> bool:
	# Test if the raycast hit a collider
	var target := hand.web_raycast.get_collider()
	if not is_instance_valid(target):
		return false
	
	# Check collider layer
	return true if target.collision_layer & web_enable_mask else false


# When the web collision mask has been modified
func _set_web_collision_mask(new_value: int) -> void:
	web_collision_mask = new_value
	if is_inside_tree() and left_hand.web_raycast and right_hand.web_raycast:
		left_hand.web_raycast.collision_mask = new_value
		right_hand.web_raycast.collision_mask = new_value


# Sets the webbing state and fire any signals
func _set_webbing(hand: WebHand, active: bool) -> void:
	#print("SET WEBBING: ", "side: ", hand.side, " active: ", active)
	
	# Skip if no change
	if active == hand.active:
		return

	# Update the is_active flag
	hand.active = active

	# Report transition&
	if hand.active:
		web_started.emit(hand.side)
	else:
		web_finished.emit(hand.side)
