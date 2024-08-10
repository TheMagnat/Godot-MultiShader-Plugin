class_name MultiShaderBakeProperty extends EditorProperty

const MULTI_SHADER_BAKE_CONTROL_SCENE = preload("res://addons/multiShader/Inspector/MultiShaderBakeControl.tscn")
var multiShaderBakeControl = MULTI_SHADER_BAKE_CONTROL_SCENE.instantiate()

var editedMultiShader = null 

func _init() -> void:
	label = "Bake"

func _ready() -> void:
	draw_warning = true
	
	editedMultiShader = get_edited_object()
	
	multiShaderBakeControl.get_node("CheckBox").toggled.connect(bakeCheckboxClicked)
	multiShaderBakeControl.get_node("CheckBox").set_pressed_no_signal(editedMultiShader.automaticBake)
	 
	multiShaderBakeControl.get_node("Button").pressed.connect(bakeButtonPressed)
	
	add_child(multiShaderBakeControl)

func bakeCheckboxClicked(checked: bool):
	editedMultiShader.automaticBake = checked

func bakeButtonPressed():
	editedMultiShader.bakeMainShader()
