class_name Vehicle
extends VehicleBody3D
## Drivable vehicle. The player enters/exits with the "interact" key (E)
## while standing near it. Physics tunables come from a VehicleStats resource.
## The vehicle faces +Z (Godot's VehicleBody3D convention); left side is +X.

const MS_TO_KMH: float = 3.6

## Physics parameters of this vehicle (a .tres file in data/vehicles/).
@export var stats: VehicleStats

@export_group("Controls")
## Below this speed S switches from braking to reverse, and W from braking to driving forward.
@export var direction_switch_speed_kmh: float = 3.0
## How many times further the steering wheel turns than the road wheels.
@export var steering_wheel_ratio: float = 6.0

@export_group("Look")
## Radians of camera rotation per pixel of mouse movement.
@export var mouse_sensitivity: float = 0.0025
## How far the driver can turn the head left/right, degrees.
@export var max_look_yaw_degrees: float = 140.0
## How far the driver can look up/down, degrees.
@export var max_look_pitch_degrees: float = 80.0

@export_group("Texts")
@export var enter_prompt: String = "E — сесть за руль"
@export var driving_prompt: String = "E — выйти   Пробел — ручник"
@export var speed_format: String = "%d км/ч"

var _driver: Player = null
var _nearby_player: Player = null
var _steer: float = 0.0
var _look_yaw: float = 0.0
var _look_pitch: float = 0.0

@onready var _front_wheels: Array[VehicleWheel3D] = [$WheelFrontLeft, $WheelFrontRight]
@onready var _rear_wheels: Array[VehicleWheel3D] = [$WheelRearLeft, $WheelRearRight]
@onready var _driver_head: Node3D = $DriverHead
@onready var _driver_camera: Camera3D = $DriverHead/Camera3D
@onready var _exit_point: Marker3D = $ExitPoint
@onready var _enter_area: Area3D = $EnterArea
@onready var _steering_wheel: Node3D = $SteeringColumn/SteeringWheel
@onready var _prompt_label: Label = $HUD/Prompt
@onready var _speed_label: Label = $HUD/Speed


func _ready() -> void:
	assert(stats != null, "Vehicle needs a VehicleStats resource")
	_apply_stats()
	_enter_area.body_entered.connect(_on_enter_area_body_entered)
	_enter_area.body_exited.connect(_on_enter_area_body_exited)
	_update_look()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _driver != null:
			_exit_vehicle()
			get_viewport().set_input_as_handled()
		elif _nearby_player != null:
			_enter_vehicle(_nearby_player)
			get_viewport().set_input_as_handled()
	elif _driver != null and event is InputEventMouseMotion \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		var max_yaw: float = deg_to_rad(max_look_yaw_degrees)
		var max_pitch: float = deg_to_rad(max_look_pitch_degrees)
		_look_yaw = clampf(_look_yaw - motion.relative.x * mouse_sensitivity, -max_yaw, max_yaw)
		_look_pitch = clampf(_look_pitch - motion.relative.y * mouse_sensitivity, -max_pitch, max_pitch)
		_update_look()


func _process(_delta: float) -> void:
	_update_hud()


func _physics_process(delta: float) -> void:
	if _driver == null:
		# Parked: no throttle, wheels held so it doesn't roll down hills.
		_steer = move_toward(_steer, 0.0, deg_to_rad(stats.steer_speed_degrees) * delta)
		_apply_controls(0.0, stats.handbrake_force, stats.handbrake_force)
		return

	var speed_kmh: float = get_forward_speed_kmh()
	var throttle: float = Input.get_action_strength("vehicle_throttle")
	var brake_pedal: float = Input.get_action_strength("vehicle_brake")
	var engine: float = 0.0
	var brake_amount: float = 0.0

	if throttle > 0.0:
		if speed_kmh < -direction_switch_speed_kmh:
			brake_amount += throttle * stats.brake_force
		elif speed_kmh < stats.max_speed_kmh:
			engine += throttle * stats.engine_force
	if brake_pedal > 0.0:
		if speed_kmh > direction_switch_speed_kmh:
			brake_amount += brake_pedal * stats.brake_force
		elif speed_kmh > -stats.max_reverse_speed_kmh:
			engine -= brake_pedal * stats.reverse_force

	# Positive steering turns left.
	var steer_input: float = Input.get_axis("vehicle_steer_right", "vehicle_steer_left")
	var speed_ratio: float = clampf(absf(speed_kmh) / stats.max_speed_kmh, 0.0, 1.0)
	var max_steer: float = deg_to_rad(stats.max_steer_degrees) \
			* lerpf(1.0, stats.steer_limit_at_max_speed, speed_ratio)
	_steer = move_toward(_steer, steer_input * max_steer, deg_to_rad(stats.steer_speed_degrees) * delta)

	var handbrake: float = stats.handbrake_force if Input.is_action_pressed("vehicle_handbrake") else 0.0
	_apply_controls(engine, brake_amount, handbrake)


## Speed along the vehicle's forward axis; negative when rolling backwards.
func get_forward_speed_kmh() -> float:
	return linear_velocity.dot(global_basis.z) * MS_TO_KMH


func _apply_stats() -> void:
	mass = stats.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, stats.center_of_mass_height, 0.0)
	for wheel: VehicleWheel3D in _front_wheels + _rear_wheels:
		wheel.wheel_radius = stats.wheel_radius
		wheel.wheel_rest_length = stats.suspension_rest_length
		wheel.suspension_travel = stats.suspension_travel
		wheel.suspension_stiffness = stats.suspension_stiffness
		wheel.suspension_max_force = stats.suspension_max_force
		wheel.damping_compression = stats.damping_compression
		wheel.damping_relaxation = stats.damping_relaxation
		wheel.wheel_friction_slip = stats.wheel_friction_slip
		wheel.wheel_roll_influence = stats.wheel_roll_influence
		var wheel_mesh: CylinderMesh = (wheel.get_node("Mesh") as MeshInstance3D).mesh
		wheel_mesh.top_radius = stats.wheel_radius
		wheel_mesh.bottom_radius = stats.wheel_radius
	for wheel: VehicleWheel3D in _front_wheels:
		wheel.use_as_steering = true
		wheel.use_as_traction = stats.all_wheel_drive
	for wheel: VehicleWheel3D in _rear_wheels:
		wheel.use_as_steering = false
		wheel.use_as_traction = true


## Sends engine force (total, split between driven wheels), service brake
## (every wheel) and handbrake (rear wheels) to the wheels.
func _apply_controls(engine_total: float, brake_amount: float, handbrake: float) -> void:
	var handbrake_on: bool = handbrake > 0.0
	var driven: Array[VehicleWheel3D] = []
	for wheel: VehicleWheel3D in _front_wheels + _rear_wheels:
		# Godot ignores a wheel's brake while it has engine force,
		# so a locked rear wheel must not be driven.
		var locked: bool = handbrake_on and wheel in _rear_wheels
		if wheel.use_as_traction and not locked:
			driven.append(wheel)
		wheel.engine_force = 0.0
	var per_wheel: float = engine_total / driven.size() if not driven.is_empty() else 0.0
	for wheel: VehicleWheel3D in driven:
		wheel.engine_force = per_wheel

	for wheel: VehicleWheel3D in _front_wheels:
		wheel.brake = brake_amount
		wheel.steering = _steer
	for wheel: VehicleWheel3D in _rear_wheels:
		wheel.brake = maxf(brake_amount, handbrake)
	_steering_wheel.rotation.y = _steer * steering_wheel_ratio


func _enter_vehicle(player: Player) -> void:
	_driver = player
	player.set_controlled(false)
	_look_yaw = 0.0
	_look_pitch = 0.0
	_update_look()
	_driver_camera.make_current()


func _exit_vehicle() -> void:
	var player: Player = _driver
	_driver = null
	# Face the same way as the vehicle, standing upright even if it is tilted.
	var forward: Vector3 = global_basis.z
	var yaw: float = atan2(forward.x, forward.z)
	# The player looks along its -Z, so turn it around to face the vehicle's +Z.
	var facing: Basis = Basis(Vector3.UP, yaw + PI)
	player.global_transform = Transform3D(facing, _exit_point.global_position)
	player.set_controlled(true)


func _update_look() -> void:
	# The head is turned around (PI) because the camera looks along -Z.
	_driver_head.rotation = Vector3(_look_pitch, PI + _look_yaw, 0.0)


func _update_hud() -> void:
	if _driver != null:
		_prompt_label.text = driving_prompt
		_prompt_label.visible = true
		_speed_label.text = speed_format % roundi(absf(get_forward_speed_kmh()))
		_speed_label.visible = true
	else:
		_prompt_label.text = enter_prompt
		_prompt_label.visible = _nearby_player != null
		_speed_label.visible = false


func _on_enter_area_body_entered(body: Node3D) -> void:
	if body is Player:
		_nearby_player = body


func _on_enter_area_body_exited(body: Node3D) -> void:
	if body == _nearby_player:
		_nearby_player = null
