class_name Vehicle
extends VehicleBody3D
## Drivable vehicle with an automatic gearbox (P / R / N / D).
## The player enters/exits with the "interact" key (E) while standing near it.
## Physics tunables come from a VehicleStats resource.
## The vehicle faces +Z (Godot's VehicleBody3D convention); left side is +X.
## Gear and handbrake stay as they were when the driver gets out.

enum Gear { PARK, REVERSE, NEUTRAL, DRIVE }

const MS_TO_KMH: float = 3.6
## Below this speed (m/s) rolling resistance fades out, so a stopped vehicle doesn't jitter.
const ROLLING_RESISTANCE_FADE_SPEED: float = 0.5
const GEAR_LETTERS: Dictionary[Gear, String] = {
	Gear.PARK: "P",
	Gear.REVERSE: "R",
	Gear.NEUTRAL: "N",
	Gear.DRIVE: "D",
}
const GEAR_ACTIONS: Dictionary[String, Gear] = {
	"gear_park": Gear.PARK,
	"gear_reverse": Gear.REVERSE,
	"gear_neutral": Gear.NEUTRAL,
	"gear_drive": Gear.DRIVE,
}

## Physics parameters of this vehicle (a .tres file in data/vehicles/).
@export var stats: VehicleStats
## Gear the vehicle is in when the level starts.
@export var start_gear: Gear = Gear.PARK
## Whether the handbrake is pulled when the level starts.
@export var start_handbrake: bool = false

@export_group("Controls")
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
@export var driving_prompt: String = "E — выйти   1 P  2 R  3 N  4 D   Пробел — ручник"
@export var speed_format: String = "%s     %d км/ч"
@export var handbrake_text: String = "     РУЧНИК"

var _driver: Player = null
var _nearby_player: Player = null
var _gear: Gear = Gear.PARK
var _handbrake_on: bool = false
var _steer: float = 0.0
var _look_yaw: float = 0.0
var _look_pitch: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

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
	_gear = start_gear
	_handbrake_on = start_handbrake
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
		return
	if _driver == null:
		return
	if event.is_action_pressed("vehicle_handbrake"):
		_handbrake_on = not _handbrake_on
		get_viewport().set_input_as_handled()
		return
	for action: String in GEAR_ACTIONS:
		if event.is_action_pressed(action):
			shift_to(GEAR_ACTIONS[action])
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		var max_yaw: float = deg_to_rad(max_look_yaw_degrees)
		var max_pitch: float = deg_to_rad(max_look_pitch_degrees)
		_look_yaw = clampf(_look_yaw - motion.relative.x * mouse_sensitivity, -max_yaw, max_yaw)
		_look_pitch = clampf(_look_pitch - motion.relative.y * mouse_sensitivity, -max_pitch, max_pitch)
		_update_look()


func _process(_delta: float) -> void:
	_update_hud()


func _physics_process(delta: float) -> void:
	var speed_kmh: float = get_forward_speed_kmh()
	var throttle: float = 0.0
	var brake_pedal: float = 0.0
	var steer_input: float = 0.0
	if _driver != null:
		throttle = Input.get_action_strength("vehicle_throttle")
		brake_pedal = Input.get_action_strength("vehicle_brake")
		# Positive steering turns left.
		steer_input = Input.get_axis("vehicle_steer_right", "vehicle_steer_left")

	var engine: float = 0.0
	var brake_amount: float = brake_pedal * stats.brake_force
	match _gear:
		Gear.PARK:
			brake_amount = maxf(brake_amount, stats.park_brake_force)
		Gear.DRIVE:
			engine = _drive_force(speed_kmh, throttle, stats.engine_force, stats.max_speed_kmh)
		Gear.REVERSE:
			engine = -_drive_force(-speed_kmh, throttle, stats.reverse_force, stats.max_reverse_speed_kmh)
		Gear.NEUTRAL:
			pass
	if brake_pedal > 0.0:
		# Godot ignores a wheel's brake while it has engine force.
		engine = 0.0

	# Without a driver the steering wheel stays where it was left.
	if _driver != null:
		_steer = _next_steer(steer_input, speed_kmh, delta)

	var handbrake: float = stats.handbrake_force if _handbrake_on else 0.0
	_apply_controls(engine, brake_amount, handbrake)
	_apply_resistance()


## Speed along the vehicle's forward axis; negative when rolling backwards.
func get_forward_speed_kmh() -> float:
	return linear_velocity.dot(global_basis.z) * MS_TO_KMH


func get_gear() -> Gear:
	return _gear


func is_handbrake_on() -> bool:
	return _handbrake_on


## Moves the selector to [param gear]. Like a real automatic, P and R can't be
## selected while moving forward, and P/D can't be selected while rolling back.
## Returns false if the shift was refused.
func shift_to(gear: Gear) -> bool:
	var speed_kmh: float = get_forward_speed_kmh()
	var limit: float = stats.shift_lock_speed_kmh
	var allowed: bool = true
	match gear:
		Gear.PARK:
			allowed = absf(speed_kmh) <= limit
		Gear.REVERSE:
			allowed = speed_kmh <= limit
		Gear.DRIVE:
			allowed = speed_kmh >= -limit
	if allowed:
		_gear = gear
	return allowed


## Engine force in the direction of travel for D (or R, with speed mirrored):
## full throttle up to top speed, otherwise the gentle idle creep of an automatic.
func _drive_force(speed_kmh: float, throttle: float, force: float, max_speed_kmh: float) -> float:
	if speed_kmh >= max_speed_kmh:
		return 0.0
	if throttle > 0.0:
		return maxf(throttle * force, stats.creep_force)
	if not _handbrake_on and speed_kmh < stats.creep_speed_kmh:
		return stats.creep_force
	return 0.0


## Moves the front wheels toward where the driver steers, at a limited rate
## (like turning a real steering wheel). The reachable angle shrinks with speed.
func _next_steer(steer_input: float, speed_kmh: float, delta: float) -> float:
	var speed_ratio: float = absf(speed_kmh) / stats.steer_half_angle_speed_kmh
	var max_steer: float = deg_to_rad(stats.max_steer_degrees) / (1.0 + speed_ratio * speed_ratio)
	var target: float = steer_input * max_steer
	var returning: bool = absf(target) < absf(_steer) or target * _steer < 0.0
	var rate_degrees: float = stats.steer_return_speed_degrees if returning else stats.steer_speed_degrees
	return move_toward(_steer, target, deg_to_rad(rate_degrees) * delta)


## Rolling resistance and air drag as real forces against the motion.
## (Godot's built-in linear damping is switched off in _apply_stats.)
func _apply_resistance() -> void:
	var velocity: Vector3 = linear_velocity
	var speed: float = velocity.length()
	if speed <= 0.0:
		return
	var direction: Vector3 = velocity / speed
	var drag: float = stats.air_drag * speed * speed
	var rolling: float = 0.0
	if _any_wheel_on_ground():
		# Fades in from zero so a stopped vehicle doesn't jitter back and forth.
		var fade: float = clampf(speed / ROLLING_RESISTANCE_FADE_SPEED, 0.0, 1.0)
		rolling = stats.rolling_resistance * mass * _gravity * fade
	apply_central_force(-direction * (drag + rolling))


func _any_wheel_on_ground() -> bool:
	for wheel: VehicleWheel3D in _front_wheels + _rear_wheels:
		if wheel.is_in_contact():
			return true
	return false


func _apply_stats() -> void:
	mass = stats.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, stats.center_of_mass_height, stats.center_of_mass_forward)
	# The project's default damping (0.1) would act like a constant hidden brake;
	# slowing down is modelled by _apply_resistance() instead.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	for wheel: VehicleWheel3D in _front_wheels + _rear_wheels:
		wheel.wheel_radius = stats.wheel_radius
		wheel.wheel_rest_length = stats.suspension_rest_length
		wheel.suspension_travel = stats.suspension_travel
		wheel.suspension_stiffness = stats.suspension_stiffness
		wheel.suspension_max_force = stats.suspension_max_force
		wheel.damping_compression = stats.damping_compression
		wheel.damping_relaxation = stats.damping_relaxation
		wheel.wheel_roll_influence = stats.wheel_roll_influence
		var wheel_mesh: CylinderMesh = (wheel.get_node("Mesh") as MeshInstance3D).mesh
		wheel_mesh.top_radius = stats.wheel_radius
		wheel_mesh.bottom_radius = stats.wheel_radius
	for wheel: VehicleWheel3D in _front_wheels:
		wheel.wheel_friction_slip = stats.front_friction_slip
		wheel.use_as_steering = true
		wheel.use_as_traction = stats.all_wheel_drive
	for wheel: VehicleWheel3D in _rear_wheels:
		wheel.wheel_friction_slip = stats.rear_friction_slip
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
		var text: String = speed_format % [_gear_strip(), roundi(absf(get_forward_speed_kmh()))]
		if _handbrake_on:
			text += handbrake_text
		_speed_label.text = text
		_speed_label.visible = true
	else:
		_prompt_label.text = enter_prompt
		_prompt_label.visible = _nearby_player != null
		_speed_label.visible = false


## "P R N [D]" — all gears with the current one in brackets.
func _gear_strip() -> String:
	var parts: PackedStringArray = []
	for gear: Gear in GEAR_LETTERS:
		var letter: String = GEAR_LETTERS[gear]
		parts.append("[%s]" % letter if gear == _gear else letter)
	return " ".join(parts)


func _on_enter_area_body_entered(body: Node3D) -> void:
	if body is Player:
		_nearby_player = body


func _on_enter_area_body_exited(body: Node3D) -> void:
	if body == _nearby_player:
		_nearby_player = null
