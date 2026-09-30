class_name Fade
extends Control
## Black curtain used for area changes.

var _rect: ColorRect
var _busy := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect = ColorRect.new()
	_rect.color = Color(0.02, 0.015, 0.04, 0.0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


func fade_out(time: float = 0.32) -> void:
	_rect.color.a = 0.0
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 1.0, time)
	await tw.finished


func fade_in(time: float = 0.32) -> void:
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 0.0, time)
	await tw.finished


func set_black() -> void:
	_rect.color.a = 1.0
