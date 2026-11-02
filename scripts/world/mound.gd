@tool
class_name Mound
extends StaticBody3D
## Smooth low-poly hill or bump with matching collision.
## Change radius/height in the Inspector; the shape rebuilds in the editor too.

## Distance from the center to the edge where the mound meets the ground.
@export_range(0.2, 100.0, 0.1, "suffix:m") var radius: float = 5.0:
	set(value):
		radius = value
		_rebuild()
## Height of the top above the ground.
@export_range(0.05, 30.0, 0.05, "suffix:m") var height: float = 1.0:
	set(value):
		height = value
		_rebuild()
## Rings from center to edge. More = smoother slope.
@export_range(2, 32) var rings: int = 6:
	set(value):
		rings = value
		_rebuild()
## Segments around the circle. More = rounder.
@export_range(3, 64) var segments: int = 12:
	set(value):
		segments = value
		_rebuild()
@export var color: Color = Color(0.4, 0.45, 0.28):
	set(value):
		color = value
		_rebuild()

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D


func _ready() -> void:
	# Internal children are never saved into the scene file.
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance, false, Node.INTERNAL_MODE_FRONT)
	_collision = CollisionShape3D.new()
	add_child(_collision, false, Node.INTERNAL_MODE_FRONT)
	_rebuild()


func _rebuild() -> void:
	if _mesh_instance == null:
		return
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1) # flat shading for the low-poly look
	for ring: int in rings:
		var r0: float = radius * ring / rings
		var r1: float = radius * (ring + 1) / rings
		for seg: int in segments:
			var a0: float = TAU * seg / segments
			var a1: float = TAU * (seg + 1) / segments
			var inner0: Vector3 = _point(r0, a0)
			var inner1: Vector3 = _point(r0, a1)
			var outer0: Vector3 = _point(r1, a0)
			var outer1: Vector3 = _point(r1, a1)
			# Godot treats clockwise triangles as front faces.
			st.add_vertex(inner0)
			st.add_vertex(outer0)
			st.add_vertex(outer1)
			if ring > 0:
				st.add_vertex(inner0)
				st.add_vertex(outer1)
				st.add_vertex(inner1)
	st.generate_normals()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	st.set_material(material)
	var mesh: ArrayMesh = st.commit()
	_mesh_instance.mesh = mesh
	_collision.shape = mesh.create_trimesh_shape()


## Point on the surface: a cosine bump that is flat at the top and meets the ground smoothly.
func _point(r: float, angle: float) -> Vector3:
	var h: float = height * 0.5 * (1.0 + cos(PI * r / radius))
	return Vector3(cos(angle) * r, h, sin(angle) * r)
