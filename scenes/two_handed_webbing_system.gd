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

## web state
enum WebState {
	IDLE,			## web is idle
	FIRED,			## web is fired
	WINCHING,		## web is winching
}

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

## Probably need to add export variables for line size, maybe line material at
## some point so dev does not need to make children editable to do this.
## For now, right click on web node and make children editable to edit these
## facets.
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var rope_width := 0.02

## Air friction while webbing
@export var friction := 0.1

## Input action that triggers webbing movement. Be sure this button does not
## conflict with other functions.
@export var web_button_action := "trigger_click"

## Hand offset to apply based on our controller pose
## You can use auto if you're using the default aim_pose or grip_pose poses.
#@export_enum("auto", "aim", "grip", "palm", "disable") var hand_offset_mode: int = 0:
#		set(value):
#			hand_offset_mode = value
#			notify_property_list_changed()
#			if is_inside_tree():
#				_update_transform()

## Class that handle all variables for hands
class WebHand:
	# What and is what
	var side: Hand
	
	# Controller related ref
	var controller: XRController3D #The controller
	var controller_tracker_and_pose := ""
	
	# Web related ref
	var root: Node3D
	var web_raycast: RayCast3D #The web raycast ref
	var web_target: MeshInstance3D #The web target ref
	var line_helper: Node3D #The line helper ref
	var line: CSGCylinder3D #The line ref
	
	# State ref
	var active := false #Is this hand active
	var web_button := false #Is the button pressed on the controller
	
	# Hook related variables
	var hook_object: Node3D = null
	var hook_local := Vector3(0,0,0)
	var hook_point := Vector3(0,0,0)

var left_hand := WebHand.new()
var right_hand := WebHand.new()

func _enter_tree() -> void:
	left_hand.controller = XRHelpers.get_left_controller(self)
	right_hand.controller = XRHelpers.get_right_controller(self)
	
	#_update_transform()


# Runs when node is added to scene
func _ready() -> void:
	# In Godot 4 we must now manually call our super class ready function
	super()
	
	# Skip if running in the editor
	if Engine.is_editor_hint():
		return
		
	# Setup side for hands
	left_hand.side = Hand.LEFT
	right_hand.side = Hand.RIGHT
	
	# Line creation nodes
	left_hand.line_helper = $Left/LeftLineHelper
	left_hand.line = $Left/LeftLineHelper/Line
	right_hand.line_helper = $Right/RightLineHelper
	right_hand.line = $Right/RightLineHelper/Line
	
	# Get Raycast node
	left_hand.web_raycast = $Left/Left_Web_RayCast
	right_hand.web_raycast = $Right/Right_Web_RayCast
	
	# Get web Target Node
	left_hand.web_target = $Left/Left_Web_Target
	right_hand.web_target = $Right/Right_Web_Target
	
	#Define the root
	left_hand.root = $Left
	right_hand.root = $Right
	
	# Reparent the root so it follow the hands
	left_hand.root.reparent(left_hand.controller, true)
	right_hand.root.reparent(right_hand.controller, true)
	
	# Ensure web length is valid
	var min_hook_length := 1.5 * XRServer.world_scale
	if web_length < min_hook_length:
		web_length = min_hook_length
	
	_setup_hand(left_hand)
	_setup_hand(right_hand)


func _setup_hand(hand : WebHand):
	# Set ray-cast
	hand.web_raycast.target_position = Vector3(0, 0, -web_length) * XRServer.world_scale
	hand.web_raycast.collision_mask = web_collision_mask

	# Deal with line
	hand.line.radius = rope_width
	hand.line.hide()
	
	match hand.side:
		0:
			print("Left Hand")
		1:
			print("Right Hand")

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(_delta: float) -> void:
#	# If we have a controller, make sure our hand transform is updated when needed.
#	if _left_controller:
#		var tracker_and_pose: String = _left_controller.tracker + "." + _left_controller.pose
#		if _left_controller_tracker_and_pose != tracker_and_pose:
#			_left_controller_tracker_and_pose = tracker_and_pose
#			if hand_offset_mode == 0:
#				_update_transform()

# Update the webbing line and target
func _physics_process(_delta: float) -> void:
	# Skip if running in the editor
	if Engine.is_editor_hint():
		return
	
	_calculate_target_visibility(left_hand)
	_calculate_target_visibility(right_hand)

	_calculate_webbing_line(left_hand)
	_calculate_webbing_line(right_hand)
	

## If pointing web at target then show the target
func _calculate_target_visibility(hand : WebHand):
	print(hand.web_raycast.is_colliding())
	print(hand.web_raycast.get_collider())
	
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


# Check property config
#func _validate_property(property: Dictionary) -> void:
#	if hand_offset_mode != 4 and (
#			property.name == "position"
#			or property.name == "rotation"
#			or property.name == "scale"
#			or property.name == "rotation_edit_mode"
#			or property.name == "rotation_order"
#	):
#		# We control these, don't let the user set them.
#		property.usage = PROPERTY_USAGE_NONE


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
	
	var do_left_impulse = _update_hand(left_hand)
	var do_right_impulse = _update_hand(right_hand)
	
	if not left_hand.active and not right_hand.active:
		return false

	# Apply gravity
	player_body.velocity += player_body.gravity * delta
	
	# Get web force and cache it
	var web_force := Vector3.ZERO
	
	web_force += _get_web_force(left_hand, player_body.velocity, do_left_impulse)
	web_force += _get_web_force(right_hand, player_body.velocity, do_right_impulse)
	
	# Apply the web force
	player_body.velocity += web_force
	
	# Scale down velocity
	player_body.velocity *= 1.0 - friction * delta

	# Perform exclusive movement as we have dealt with gravity
	player_body.velocity = player_body.move_player(player_body.velocity)
	
	print("This web is being used : " + name)
	
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
	var old_button := hand.web_button
	hand.web_button = hand.controller.is_button_pressed(web_button_action)
	
	# Enable/disable webbing
	var do_impulse := false
	if hand.active and not hand.web_button:
		_set_webbing(hand, false)
	elif hand.web_button and not old_button and _is_raycast_valid(hand):
		hand.hook_object = hand.web_raycast.get_collider()
		hand.hook_point = hand.web_raycast.get_collision_point()
		hand.hook_local = hand.hook_point * hand.hook_object.global_transform
		
		do_impulse = true
		_set_webbing(hand, true)
		
	#print("----------------")
	#print("Pressed :", hand.web_button)
	#print("Old :", old_button)
	#print("Raycast :", _is_raycast_valid(hand))
	return do_impulse

## Return a Vector3 that is the force that need to be applied to the player
func _get_web_force(hand: WebHand, player_velocity: Vector3, do_impulse: bool) -> Vector3:
	if not hand.active:
		return Vector3.ZERO
	
	# Get hook direction
	hand.hook_point = hand.hook_object.global_transform * hand.hook_local
	var hook_vector := hand.hook_point - hand.controller.global_transform.origin
	var hook_length := hook_vector.length()
	var hook_direction := hook_vector / hook_length
	
	# Select the web speed
	var speed := impulse_speed if do_impulse else winch_speed
	if hook_length < 1.0:
		speed = 0.0

	# Ensure velocity is at least winch_speed towards hook
	var vdot: float = player_velocity.dot(hook_direction)
	if vdot < speed:
		return hook_direction * (speed - vdot)
	
	print("GET WEB FORCE")
	return Vector3.ZERO


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
	print("SET WEBBING", hand.side, active)
	
	# Skip if no change
	if active == hand.active:
		return

	# Update the is_active flag
	hand.active = active

	# Report transition
	if hand.active:
		web_started.emit(hand.side)
	else:
		web_finished.emit(hand.side)


# Updates our transform so we are positioned on our palm
#func _update_transform() -> void:
#	if hand_offset_mode != 4:
#		transform = XRTools.get_palm_offset(hand_offset_mode, left_hand.controller)
#		transform = XRTools.get_palm_offset(hand_offset_mode, right_hand.controller)
