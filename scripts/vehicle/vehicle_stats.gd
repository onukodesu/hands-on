class_name VehicleStats
extends Resource
## Tunable physics parameters of one vehicle model.
## Stored as a .tres file under data/vehicles/ and edited in the Inspector,
## so a vehicle can be tuned (or added by a mod) without touching code.

@export_group("Body")
## Total mass of the vehicle.
@export_range(300.0, 10000.0, 10.0, "suffix:kg") var mass: float = 1800.0
## Height of the center of mass relative to the body origin (wheel mount level).
## Higher = more body lean outward in turns and easier to flip.
## Below about -0.1 the body starts leaning INTO turns, which is unrealistic.
@export_range(-1.0, 1.0, 0.01, "suffix:m") var center_of_mass_height: float = 0.35
## Shift of the center of mass toward the front (+) or rear (-).
## Real SUVs are front-heavy, which makes them push wide in fast turns
## (understeer) instead of spinning.
@export_range(-1.0, 1.0, 0.01, "suffix:m") var center_of_mass_forward: float = 0.15

@export_group("Engine")
## Drive all four wheels. Off = rear-wheel drive only.
@export var all_wheel_drive: bool = true
## Total pushing force of the engine going forward, split between driven wheels.
@export_range(0.0, 50000.0, 100.0, "suffix:N") var engine_force: float = 7000.0
## Total pushing force in reverse.
@export_range(0.0, 50000.0, 100.0, "suffix:N") var reverse_force: float = 4000.0
## The engine stops pushing above this speed.
@export_range(5.0, 300.0, 1.0, "suffix:km/h") var max_speed_kmh: float = 100.0
## Top speed in reverse.
@export_range(1.0, 100.0, 1.0, "suffix:km/h") var max_reverse_speed_kmh: float = 25.0

@export_group("Gearbox")
## In D (or R) without throttle the vehicle creeps up to this speed, like a real automatic.
@export_range(0.0, 30.0, 0.5, "suffix:km/h") var creep_speed_kmh: float = 7.0
## Total pushing force while creeping.
@export_range(0.0, 20000.0, 100.0, "suffix:N") var creep_force: float = 2500.0
## P, R and D can only be selected below this speed (in the "wrong" direction).
@export_range(0.0, 30.0, 0.5, "suffix:km/h") var shift_lock_speed_kmh: float = 3.0

@export_group("Brakes")
## Brake strength on each wheel (S).
@export_range(0.0, 500.0, 1.0) var brake_force: float = 50.0
## Handbrake strength on each rear wheel (Space toggles it).
@export_range(0.0, 500.0, 1.0) var handbrake_force: float = 80.0
## How hard P locks all four wheels.
@export_range(0.0, 1000.0, 1.0) var park_brake_force: float = 200.0

@export_group("Resistance")
## Tire rolling resistance: constant slowing force, as a share of the vehicle's
## weight (0.015 asphalt, 0.03-0.05 off-road tires on dirt).
@export_range(0.0, 0.3, 0.001) var rolling_resistance: float = 0.03
## Air drag: slowing force = this × speed² (speed in m/s).
## Roughly 0.5 × air density × drag coefficient × frontal area.
@export_range(0.0, 5.0, 0.01, "suffix:N·s²/m²") var air_drag: float = 0.8

@export_group("Steering")
## Maximum angle of the front wheels when standing still.
@export_range(5.0, 60.0, 0.5, "suffix:°") var max_steer_degrees: float = 35.0
## How fast the wheels turn away from center, degrees per second
## (35° in 0.7 s = 50°/s).
@export_range(5.0, 720.0, 1.0, "suffix:°/s") var steer_speed_degrees: float = 50.0
## How fast the wheels return toward center, degrees per second.
@export_range(5.0, 720.0, 1.0, "suffix:°/s") var steer_return_speed_degrees: float = 50.0
## Speed at which the maximum steering angle is halved. Above it the angle
## keeps shrinking: at 3× this speed only a tenth of the angle is left.
@export_range(5.0, 200.0, 0.5, "suffix:km/h") var steer_half_angle_speed_kmh: float = 28.0

@export_group("Suspension")
## Spring stiffness. Lower = softer, the body sways more.
@export_range(5.0, 200.0, 0.5) var suspension_stiffness: float = 22.0
## Spring length at rest (how far the wheel hangs from the body).
@export_range(0.1, 1.5, 0.01, "suffix:m") var suspension_rest_length: float = 0.45
## How far the spring can compress.
@export_range(0.05, 1.0, 0.01, "suffix:m") var suspension_travel: float = 0.3
## Upper limit of one spring's force. Must stay well above mass × 9.8 ÷ 4.
@export_range(1000.0, 100000.0, 100.0, "suffix:N") var suspension_max_force: float = 18000.0
## Damping while the spring compresses (wheel hits a bump). Lower = bouncier.
@export_range(0.0, 10.0, 0.05) var damping_compression: float = 1.2
## Damping while the spring extends back. Usually a bit higher than compression.
@export_range(0.0, 10.0, 0.05) var damping_relaxation: float = 2.0

@export_group("Wheels")
## Wheel radius (also resizes the wheel model).
@export_range(0.2, 1.2, 0.01, "suffix:m") var wheel_radius: float = 0.42
## Grip of the front tires. Lower than the rear = the front slides first
## in fast turns (understeer, safe), higher = the rear slides first (spin).
@export_range(0.5, 20.0, 0.1) var front_friction_slip: float = 0.8
## Grip of the rear tires.
@export_range(0.5, 20.0, 0.1) var rear_friction_slip: float = 1.0
## How much side forces tilt the body. 0 = never rolls, 1 = realistic and easy to flip.
@export_range(0.0, 1.0, 0.01) var wheel_roll_influence: float = 0.1
