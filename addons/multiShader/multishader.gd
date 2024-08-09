@tool
extends EditorPlugin

# A class member to hold the inspector plugin during its life cycle.
var inspectorPlugin: MultiShaderInspector

func _enter_tree():
	inspectorPlugin = MultiShaderInspector.new()
	add_inspector_plugin(inspectorPlugin)

func _exit_tree():
	remove_inspector_plugin(inspectorPlugin)
