class_name MultiShaderInspector extends EditorInspectorPlugin


func _can_handle(object: Object) -> bool:
	return object is MultiShaderMaterial

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if name == "automaticBake":
		add_custom_control(MultiShaderBakeProperty.new())
		return true

	return false
