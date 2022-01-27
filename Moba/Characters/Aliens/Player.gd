extends CharacterBody2D
class_name Player

const SPEED = 300.0
const JUMP_FORCE = -400.0
const MAX_JUMP_FUEL = 100.0

# Get the gravity from the project settings to be synced with RigidDynamicBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var sync_position : Vector2
var jump_fuel := MAX_JUMP_FUEL
var sync_is_jumping := false

func _ready():
	$Camera2D.current = is_local_authority()
	$UI.visible = is_local_authority()

func is_local_authority() -> bool:
	return name == str(multiplayer.get_unique_id())

func _process(_delta):
	$UI/TextureProgressBar.value = jump_fuel
	$UI/TextureProgressBar.visible = jump_fuel < MAX_JUMP_FUEL
	
	# Note, this is a CPU Particles node named GPUParticles!
	# Godot 4 currently has a bug where GPU Particles in global space are incorrectly offset
	# https://github.com/godotengine/godot/issues/56892
	$GPUParticles2D.emitting = sync_is_jumping

func _physics_process(delta):
	if !is_local_authority():
		# TODO lerp to sync_position
		position = sync_position
		return

	# Add the gravity.
	if not is_on_floor():
		motion_velocity.y += gravity * delta

	# Handle Jump.
	if Input.is_action_pressed("jump") and jump_fuel >= 0:
		motion_velocity.y = JUMP_FORCE
		jump_fuel -= 1
		sync_is_jumping = true
	else:
		sync_is_jumping = false
	
	if is_on_floor():
		jump_fuel = MAX_JUMP_FUEL

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction = Input.get_axis("move_left", "move_right")
	if direction:
		motion_velocity.x = direction * SPEED
	else:
		motion_velocity.x = move_toward(motion_velocity.x, 0, SPEED)
	
	# Move locally
	move_and_slide()
	
	# Sync position to the server
	rpc_id(1, StringName('push_to_server'), position, sync_is_jumping)

@rpc(any_peer, unreliable_ordered)
func push_to_server(newPosition : Vector2, is_jumping : bool):
	# Validate!
	if name != str(multiplayer.get_remote_sender_id()):
		print('someone being naughty! ', multiplayer.get_remote_sender_id(), ' tried to update ', name)
		return
	sync_position = newPosition
	sync_is_jumping = is_jumping
