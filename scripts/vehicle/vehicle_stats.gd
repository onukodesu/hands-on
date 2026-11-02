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
@export_range(-1.0, 1.0, 0.01, "suffix:m") var center_of_mass_height: float = 0.0

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
## Small constant braking on every wheel (tires, bearings), so a coasting
## vehicle slowly stops on flat ground.
@export_range(0.0, 20.0, 0.1) var rolling_resistance: float = 0.4

@export_group("Steering")
## Maximum angle of the front wheels at low speed.
@export_range(5.0, 60.0, 0.5, "suffix:°") var max_steer_degrees: float = 32.0
## How fast the front wheels turn, degrees per second.
@export_range(10.0, 720.0, 5.0, "suffix:°/s") var steer_speed_degrees: float = 100.0
## Share of the maximum steering angle left at top speed (1 = no limit).
## Keeps the vehicle from flipping in fast turns.
@export_range(0.05, 1.0, 0.01) var steer_limit_at_max_speed: float = 0.2

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
## Tire grip. Lower = slides more, higher = grips but rolls over easier.
@export_range(0.5, 20.0, 0.1) var wheel_friction_slip: float = 4.0
## How much side forces tilt the body. 0 = never rolls, 1 = realistic and easy to flip.
@export_range(0.0, 1.0, 0.01) var wheel_roll_influence: float = 0.1
