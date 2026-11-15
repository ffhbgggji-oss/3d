extends Control
class_name BoneOverlay

## Screen-space skeleton and touch-friendly transform gizmo.
var target_skeleton: Skeleton3D
var target_camera: Camera3D
var selected_bone: int = -1
var tool_mode: String = "rotate"
var selected_axis: String = "screen"
var overlay_enabled: bool = true
var top_reserved: float = 224.0
var bottom_reserved: float = 160.0

const BONE_COLOR := Color(0.78, 0.80, 0.84, 0.88)
const SELECTED_COLOR := Color(1.0, 0.55, 0.12, 1.0)
const X_COLOR := Color(0.96, 0.20, 0.24, 1.0)
const Y_COLOR := Color(0.18, 0.88, 0.30, 1.0)
const Z_COLOR := Color(0.18, 0.48, 1.0, 1.0)
const HANDLE_HIT_RADIUS := 42.0
const HANDLE_LENGTH_PX := 118.0
const HANDLE_START_PX := 23.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(skeleton: Skeleton3D, camera: Camera3D, selected: int, mode: String, enabled: bool = true, safe_top: float = 224.0, safe_bottom: float = 160.0, axis: String = "screen") -> void:
    target_skeleton = skeleton
    target_camera = camera
    selected_bone = selected
    tool_mode = mode
    selected_axis = axis
    overlay_enabled = enabled
    top_reserved = safe_top
    bottom_reserved = safe_bottom
    queue_redraw()

func _axis_color(axis: String) -> Color:
    match axis:
        "X": return X_COLOR
        "Y": return Y_COLOR
        "Z": return Z_COLOR
    return Color.WHITE

func _axis_world(axis: String) -> Vector3:
    var local_axis := Vector3.RIGHT
    match axis:
        "X": local_axis = Vector3.RIGHT
        "Y": local_axis = Vector3.UP
        "Z": local_axis = Vector3.FORWARD
    return (target_skeleton.global_basis.orthonormalized() * local_axis).normalized()

func _handle_points(axis: String, center: Vector2) -> PackedVector2Array:
    var world := target_skeleton.global_transform * target_skeleton.get_bone_global_pose(selected_bone).origin
    var direction := _axis_world(axis)
    var depth := maxf(0.1, target_camera.global_position.distance_to(world))
    var viewport_height := maxf(1.0, get_viewport_rect().size.y)
    var world_per_pixel: float
    if target_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
        world_per_pixel = target_camera.size / viewport_height
    else:
        world_per_pixel = 2.0 * depth * tan(deg_to_rad(target_camera.fov) * 0.5) / viewport_height
    var world_length := world_per_pixel * HANDLE_LENGTH_PX
    var endpoint_world := world + direction * world_length
    var endpoint := target_camera.unproject_position(endpoint_world)
    var projected := endpoint - center
    if projected.length() < 0.001:
        return PackedVector2Array([center, center])
    var screen_dir := projected.normalized()
    return PackedVector2Array([center + screen_dir * HANDLE_START_PX, center + screen_dir * HANDLE_LENGTH_PX])

func pick_axis(screen_position: Vector2) -> String:
    if selected_bone < 0 or not is_instance_valid(target_skeleton) or not is_instance_valid(target_camera):
        return ""
    var world := target_skeleton.global_transform * target_skeleton.get_bone_global_pose(selected_bone).origin
    if target_camera.is_position_behind(world):
        return ""
    var center := target_camera.unproject_position(world)
    var best_axis := ""
    var best_distance := HANDLE_HIT_RADIUS
    for axis_name in ["X", "Y", "Z"]:
        var points := _handle_points(axis_name, center)
        var a: Vector2 = points[0]
        var b: Vector2 = points[1]
        var ab := b - a
        var t := clampf((screen_position - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
        var distance := screen_position.distance_to(a + ab * t)
        # Prefer the nearest handle; the central joint is deliberately not a handle.
        if distance < best_distance:
            best_distance = distance
            best_axis = axis_name
    return best_axis

func _draw() -> void:
    if not overlay_enabled or not is_instance_valid(target_skeleton) or not is_instance_valid(target_camera):
        return
    var points: Dictionary = {}
    for i in range(target_skeleton.get_bone_count()):
        var world := target_skeleton.global_transform * target_skeleton.get_bone_global_pose(i).origin
        if target_camera.is_position_behind(world):
            continue
        var screen_point := target_camera.unproject_position(world)
        var viewport_height := get_viewport_rect().size.y
        if screen_point.y < top_reserved or screen_point.y > viewport_height - bottom_reserved:
            continue
        points[i] = screen_point
    for i in range(target_skeleton.get_bone_count()):
        if not points.has(i):
            continue
        var parent := target_skeleton.get_bone_parent(i)
        if parent >= 0 and points.has(parent):
            var line_color := SELECTED_COLOR if int(i) == selected_bone else BONE_COLOR
            var line_width := 4.0 if int(i) == selected_bone else 2.2
            draw_line(points[parent], points[i], line_color, line_width, true)
    for i in points.keys():
        var p: Vector2 = points[i]
        var color := SELECTED_COLOR if int(i) == selected_bone else BONE_COLOR
        var radius := 7.0 if int(i) == selected_bone else 4.5
        draw_circle(p, radius + 1.5, Color(0.12, 0.13, 0.15, 0.9))
        draw_circle(p, radius, color)
    if selected_bone >= 0 and points.has(selected_bone):
        _draw_transform_gizmo(points[selected_bone])

func _draw_transform_gizmo(c: Vector2) -> void:
    if tool_mode == "move" or tool_mode == "scale":
        for axis_name in ["X", "Y", "Z"]:
            var points := _handle_points(axis_name, c)
            var a: Vector2 = points[0]
            var b: Vector2 = points[1]
            var color := _axis_color(axis_name)
            var active := selected_axis == axis_name
            var width := 15.0 if active else 11.0
            draw_line(a, b, Color(0.04, 0.05, 0.07, 0.92), width + 5.0, true)
            draw_line(a, b, color, width, true)
            if tool_mode == "move":
                var d := (b - a).normalized()
                var side := Vector2(-d.y, d.x) * (15.0 if active else 12.0)
                draw_colored_polygon(PackedVector2Array([b, b - d * 25.0 + side, b - d * 25.0 - side]), color)
            else:
                draw_rect(Rect2(b - Vector2(10, 10), Vector2(20, 20)), color, true)
            draw_circle(b, 17.0 if active else 13.0, Color(0.05, 0.06, 0.08, 0.95))
            draw_circle(b, 12.0 if active else 9.0, color)
            draw_string(ThemeDB.fallback_font, b + Vector2(15, -13), axis_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, color)
        draw_circle(c, 9.0, SELECTED_COLOR)
    elif tool_mode == "rotate":
        draw_arc(c, 48.0, 0.0, TAU, 64, X_COLOR, 6.0, true)
        draw_arc(c, 39.0, PI * 0.15, PI * 1.15, 48, Y_COLOR, 6.0, true)
        draw_arc(c, 30.0, PI * 0.85, PI * 1.85, 48, Z_COLOR, 6.0, true)
        draw_circle(c, 7.0, SELECTED_COLOR)
