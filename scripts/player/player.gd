class_name Player
extends CharacterBody3D
## First-person player: WASD movement, mouse look, jump and sprint.
## Mouse capture (Esc / click) is handled by the MouseCapture autoload.

@export_group("Movement")
## Walking speed, m/s.
@export var walk_speed: float = 4.0
## Speed while holding Shift, m/s.
@export var sprint_speed: float = 7.0
## How fast the player speeds up and slows down, m/s².
@export var acceleration: float = 40.0
## Upward speed at the start of a jump, m/s.
@export var jump_velocity: float = 4.5

@export_group("Look")
## Radians of rotation per pixel of mouse movement.
@export var mouse_sensitivity: float = 0.0025
## How far up/down the player can look, degrees.
@export var max_pitch_degrees: float = 89.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D


## Turns the on-foot player on or off (e.g. while sitting in a vehicle).
## When off, the player is hidden, ignores input and has no collision.
func set_controlled(active: bool) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	visible = active
	velocity = Vector3.ZERO
	if active:
		_head.rotation.x = 0.0
		_camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative)


func _physics_process(delta: float) -> void:
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= _gravity * delta

	var input_dir: Vector2 = Input.get_vector(
			"move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed: float = sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target: Vector3 = direction * speed
	var step: float = acceleration * delta
	velocity.x = move_toward(velocity.x, target.x, step)
	velocity.z = move_toward(velocity.z, target.z, step)

	move_and_slide()


func _look(mouse_delta: Vector2) -> void:
	rotate_y(-mouse_delta.x * mouse_sensitivity)
	_head.rotate_x(-mouse_delta.y * mouse_sensitivity)
	var max_pitch: float = deg_to_rad(max_pitch_degrees)
	_head.rotation.x = clampf(_head.rotation.x, -max_pitch, max_pitch)
