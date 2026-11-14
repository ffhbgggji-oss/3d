extends Control
class_name BoneOverlay

## Screen-space skeleton and transform gizmo overlay. Input is handled by RigAnimationEditor.
var target_skeleton: Skeleton3D
var target_camera: Camera3D
var selected_bone: int = -1
var tool_mode: String = "rotate"
var overlay_enabled: bool = true
var top_reserved: float = 224.0
var bottom_reserved: float = 160.0

const BONE_COLOR := Color(0.78, 0.80, 0.84, 0.88)
const SELECTED_COLOR := Color(1.0, 0.55, 0.12, 1.0)
const X_COLOR := Color(0.90, 0.18, 0.22, 1.0)
const Y_COLOR := Color(0.18, 0.82, 0.22, 1.0)
const Z_COLOR := Color(0.12, 0.36, 0.96, 1.0)

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(skeleton: Skeleton3D, camera: Camera3D, selected: int, mode: String, enabled: bool = true, safe_top: float = 224.0, safe_bottom: float = 160.0) -> void:
    target_skeleton = skeleton
    target_camera = camera
    selected_bone = selected
    tool_mode = mode
    overlay_enabled = enabled
    top_reserved = safe_top
    bottom_reserved = safe_bottom
    queue_redraw()

func pick_axis(screen_position: Vector2) -> String:
    if selected_bone < 0 or not is_instance_valid(target_skeleton) or not is_instance_valid(target_camera):
        return ""
    var world := target_skeleton.global_transform * target_skeleton.get_bone_global_pose(selected_bone).origin
    if target_camera.is_position_behind(world):
        return ""
    var c := target_camera.unproject_position(world)
    var handles := {
        "X": [c, c + Vector2(78.0, 0.0)],
        "Y": [c, c + Vector2(0.0, -78.0)],
        "Z": [c, c + Vector2(-58.0, 58.0)]
    }
    var best_axis := ""
    var best_distance := 22.0
    for axis_name in ["X", "Y", "Z"]:
        var segment: Array = handles[axis_name]
        var a: Vector2 = segment[0]
        var b: Vector2 = segment[1]
        var ab := b - a
        var t := clampf((screen_position - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
        var d := screen_position.distance_to(a + ab * t)
        if d < best_distance:
            best_distance = d
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
        var radius := 6.5 if int(i) == selected_bone else 4.5
        draw_circle(p, radius + 1.2, Color(0.12, 0.13, 0.15, 0.8))
        draw_circle(p, radius, color)
    if selected_bone >= 0 and points.has(selected_bone):
        _draw_transform_gizmo(points[selected_bone])

func _draw_transform_gizmo(c: Vector2) -> void:
    if tool_mode == "rotate":
        draw_arc(c, 43.0, 0.0, TAU, 64, X_COLOR, 4.0, true)
        draw_arc(c, 36.0, PI * 0.15, PI * 1.15, 48, Y_COLOR, 4.0, true)
        draw_arc(c, 29.0, PI * 0.85, PI * 1.85, 48, Z_COLOR, 4.0, true)
        draw_circle(c, 5.0, SELECTED_COLOR)
    elif tool_mode == "move":
        _draw_axis(c, c + Vector2(78, 0), X_COLOR)
        _draw_axis(c, c + Vector2(0, -78), Y_COLOR)
        _draw_axis(c, c + Vector2(-58, 58), Z_COLOR)
    elif tool_mode == "scale":
        _draw_scale_axis(c, c + Vector2(78, 0), X_COLOR)
        _draw_scale_axis(c, c + Vector2(0, -78), Y_COLOR)
        _draw_scale_axis(c, c + Vector2(-58, 58), Z_COLOR)
        draw_circle(c, 6.0, SELECTED_COLOR)

func _draw_axis(a: Vector2, b: Vector2, color: Color) -> void:
    draw_line(a, b, color, 7.0, true)
    var d := (b - a).normalized()
    var side := Vector2(-d.y, d.x) * 11.0
    draw_colored_polygon(PackedVector2Array([b, b - d * 20.0 + side, b - d * 20.0 - side]), color)

func _draw_scale_axis(a: Vector2, b: Vector2, color: Color) -> void:
    draw_line(a, b, color, 4.0, true)
    draw_rect(Rect2(b - Vector2(7, 7), Vector2(14, 14)), color, true)
