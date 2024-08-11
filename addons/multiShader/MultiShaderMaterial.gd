@tool
@icon("res://addons/multiShader/multiShaderIcon.png")
class_name MultiShaderMaterial extends ShaderMaterial

## A resource to help you create shader using multiple shaders but without having to
## merge them manually. Every shaders within the [member managedShaders] array will
## their lines merged together in a single newly generated shader. Multiple fragment
## and vertex functions will also have their code merged. Uniforms and variable with
## the same name will get a suffix to differenciate them unless they have the same
## type, in this case they won't get duplicated.
## [br] [br]
## Please take care of not working on a generated shader, since it can get overwritten
## if [method bakeMainShader] is called (it can be automatic if [member automaticBake] is true.
## If you really want to edit the generated shader, It is highly recommanded to save
## the generated shader in its own resource using the "save as" option in the inspector.

# When true, changing / saving any shader will trigger a new bake
## When set to true, any changes to the [member managedShaders] will launch a Bake.
## Changes to [Shader] inside the [member managedShaders] will also trigger a Bake. 
## [br] [br]
## Pressing the Bake Shader button will start a Bake.
## [br] [br]
## Baking the shader will generate a new [Shader] and fill the [member shader] property with it.
@export var automaticBake: bool = true

## Define the current shader_type of the shader.
@export_enum("Auto:-1", "Spatial:0", "Canvas:1", "Particles:2", "Sky:3", "Fog:4") var mode: int = -1:
	set(value):
		# If value is auto mode, set mode and if managgedShaders is empty, set _currentMode too
		if value == -1:
			mode = value
			if managedShaders.is_empty():
				_currentMode = -1
			return
		
		if _currentMode != -1 and not managedShaders.is_empty() and value != _currentMode:
			printerr("Tried to change mode but %s is not coherent with current shaders type (%s)." % [_getShaderTypeString(value), _getShaderTypeString(_currentMode)])
			return
		
		mode = value
		_currentMode = mode

## Tell if the shaders in the [member managedShaders] are coherent between them.
## This boolean must be true for the shader baking to proceed.
var _coherentManagedShaders = false

## Store the true mode of the shader, can differ from mode if mode is set to Auto.
var _currentMode: int = -1

var _handledManagedShaders: Array[Shader]

## Shader that the MultiShaderMaterial will try to merge together when [method bakeMainShader] is called.
@export var managedShaders: Array[Shader]:
	set(value):
		if not Engine.is_editor_hint(): return
		managedShaders = value
		verifyManagedShaders()

## Contain the defined shaders macro. If edited, [method bakeMainShader] must be called
## to regenerate the shader with the new macro values.
@export var shaderMacros: Dictionary


### Variable used by the TokensHandler as a cache to keep track of conflicts
# Keep count of the number of shaders managed by the TokensHandler (to assign them an id)
var _count: int = 0
# This store for each shaders the encountered conflicts
var _conflictsPerShader := {}
# Token handler id, refer to the local scope id, will be used if conflicts are found
var _idPerShader := {}

func resetTokenHandlerCache():
	_count = 0
	_conflictsPerShader = {}
	_idPerShader = {}

## Verify and set the computation variables for the baking. It must be called before
## calling [method bakeMainShader].
## [br] [br]
## Note: [method bakeMainShader] is automaticaly called if [member automaticBake] is set to true.
func verifyManagedShaders():
	_coherentManagedShaders = false
	
	var tempoHandledManagedShaders: Array[Shader]
	for index in managedShaders.size():
		var shaderRef: Shader = managedShaders[index]
		if not shaderRef:
			continue
		
		if _currentMode == -1:
			_currentMode = shaderRef.get_mode()
		elif _currentMode != shaderRef.get_mode():
			printerr("Shader at index %d type is not coherent. (expected %s but got %s)" % [index, _getShaderTypeString(_currentMode), _getShaderTypeString(shaderRef.get_mode())])
			return
		
		tempoHandledManagedShaders.push_back(shaderRef)
	
	_handledManagedShaders = tempoHandledManagedShaders
	if _handledManagedShaders.is_empty():
		if mode == -1:
			_currentMode = -1
		return
	
	# All shaders look valid, connect the changed event on them
	for shaderRef in _handledManagedShaders:
		if not shaderRef.changed.is_connected(bakeMainShader):
			shaderRef.changed.connect(bakeMainShader)
	
	_coherentManagedShaders = true
	
	if automaticBake:
		bakeMainShader()

var _shadersData := {}
func _parseShader(shaderRef: Shader):
	
	_shadersData[shaderRef] = {
		#"code": "",
		"tokens": [],
		"vertex": [],
		"fragment": []
	}
	
	var toMerge = []
	
	# Function scope
	var currentFunction = null
	var brace_count = 0
	
	# Store the vertex code
	var vertexCode: String = shaderRef.code
	var generatedTokens: Array[Token]
	
	# Parameters
	var lineEndChars: String = ";{}"
	var mergeFunctions: PackedStringArray = ["vertex", "fragment"]
	
	# Comment handling
	var lineCommentState: bool = false
	var multiLineCommentState: bool = false
	
	# Directive handling
	var inDirective: bool = false
	
	var lineStart: int = 0
	var lineEnd: int = -1
	
	var skipOne: bool = false
	for i in vertexCode.length():
		if skipOne:
			skipOne = false
			continue

		if not multiLineCommentState and i > 0 and vertexCode[i-1] == "/" and vertexCode[i] == "*":
			multiLineCommentState = true
			#Note: Here we jump one index to prevent to consider line like /*/ like an end of comment
			skipOne = true
		
		if multiLineCommentState:
			# Leave the comment state
			if vertexCode[i-1] == "*" and vertexCode[i] == "/":
				multiLineCommentState = false
			
			continue
		
		#TODO: Start at 1 and ignore the test i > 0
		if not lineCommentState and i > 0 and vertexCode[i-1] == "/" and vertexCode[i] == "/":
			lineCommentState = true
		
		if lineCommentState:
			# Leave the comment state
			if vertexCode[i] == "\n":
				lineCommentState = false
			
			continue
		
		# From here, we're now sure to not be in a comment
		
		# Verify if there is a precompilation directive
		if inDirective:
			if vertexCode[i] != "\n":
				# If current char is not '\n', directive is not finished
				continue
			
			# Here the directive ended
			inDirective = false
		else:
			if vertexCode[i] == "#":
				# Here we enter a directive
				inDirective = true
				continue
			
			elif vertexCode[i] not in lineEndChars:
				continue
		
		# Here the lined / directive ended, handle it normaly
		lineEnd = i+1
		
		var line: String = vertexCode.substr(lineStart, lineEnd - lineStart)
		line = line.strip_edges()
		if "shader_type" in line:
			# Discard shader_type line
			lineStart = lineEnd
			lineEnd = -1 # Not mendatory
			continue
		
		var lineToken = Token.new(line, lineStart, lineEnd)
		
		# Check for function declaration
		if currentFunction == null:
			if lineToken.tokenType == Token.TokenTypes.FUNCTION:
				currentFunction = lineToken
				brace_count = 1
			else:
				# Here we're not in a function and the line ended
				generatedTokens.push_back(lineToken)
		
		# Count braces to track function body
		elif currentFunction != null:
			brace_count += line.count("{") - line.count("}")
			
			# Check if function has ended
			if brace_count == 0:
				currentFunction.endIndex = lineEnd
				currentFunction.bodyEndIndex = lineStart + line.rfind("}")
				
				# Do logic depending on the function
				if currentFunction.tokenName in mergeFunctions:
					toMerge.append(currentFunction)
				else:
					generatedTokens.push_back(currentFunction)
				
				currentFunction = null
				
			# Function has not ended, add the line
			else:
				currentFunction.childs.push_back(lineToken)
		
		#Here reset line
		lineStart = lineEnd
		lineEnd = -1 # Not mendatory
	
	for functionToken in toMerge:
		_shadersData[shaderRef][functionToken.tokenName] = functionToken
	
	_shadersData[shaderRef].tokens = generatedTokens

func _getShaderTypeString(mode):
	match mode:
		0:
			return "shader_type spatial;"
		1:
			return "shader_type canvas_item;"
		2:
			return "shader_type particles;"
		3:
			return "shader_type sky;"
		4:
			return "shader_type fog;"

func _mergeShaders():
	
	var finalShader: String = "// This shader was automaticly generated by the MultiShaderMaterial.\n// DO NOT WORK ON THIS SHADER, YOUR WORK MAY GET DELETED.\n"
	finalShader += _getShaderTypeString(_currentMode) + "\n\n"
	
	var functionToCombine: PackedStringArray = ["vertex", "fragment"]
	
	# This array will be used as a cache for the local declarations
	var tokenToWatch: Array[Token] = []
	
	# Merge "normal" code
	for shaderRef in _handledManagedShaders:
		if _shadersData[shaderRef].tokens:
			var tokenHandler := TokensHandler.new(self, shaderRef, _shadersData[shaderRef].tokens, shaderMacros)
			
			# Write to the shader
			finalShader += \
				("// %s shader part\n" % shaderRef.resource_path) + \
				tokenHandler.tokenListToString(tokenToWatch) + \
				"\n"
			
			tokenToWatch += _shadersData[shaderRef].tokens
	
	# Merge the functions
	for functionName in functionToCombine:
		var finalFunction: String = "void %s() {\n" % functionName
		
		# Reset the local cache
		tokenToWatch.clear()
		
		var addedLines: int = 0
		for shaderRef in _handledManagedShaders:
			if _shadersData[shaderRef][functionName].childs:
				var tokenHandler := TokensHandler.new(self, shaderRef, _shadersData[shaderRef][functionName].childs, shaderMacros, 1)
				
				finalFunction += \
					("\t// %s shader part\n" % shaderRef.resource_path) + \
					tokenHandler.tokenListToString()
				
				addedLines += _shadersData[shaderRef][functionName].childs.size()
				
				tokenToWatch += _shadersData[shaderRef][functionName].childs
			
		finalFunction += "}\n\n"
		
		if addedLines > 0:
			finalShader += finalFunction
	
	return finalShader

## Try baking the main [class Shader].
func bakeMainShader():
	if not _coherentManagedShaders:
		printerr("MultiShader isn't in a state that allow its baking.")
		return
	
	# Make sure the TokensHandler cache is in its initial state
	resetTokenHandlerCache()
	
	# Parse each shader (Generate Tokens)
	for shaderRef in _handledManagedShaders:
		_parseShader(shaderRef)
	
	# Merge the shaders together (Use Tokens)
	var finalShaderCode: String = _mergeShaders()

	# Create a newly shader using the merged code
	var newShader = Shader.new()
	newShader.code = finalShaderCode
	newShader.resource_name = "AutoShader"
	
	# Make the new shader our current shader
	shader = newShader
