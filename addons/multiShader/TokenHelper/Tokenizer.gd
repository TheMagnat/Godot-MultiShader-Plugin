class_name Token

enum TokenTypes {EMPTY, FUNCTION, VARIABLE, UNIFORM, DEFINE_MACRO, INCLUDE_MACRO, DIRECTIVE}

var originalLine: String = ""

var tokenType: TokenTypes = TokenTypes.EMPTY
var tokenName: String
var tokenValue: String
#TODO: Make it store the function signature
var type: String # Can be the type of the variable

var startIndex: int
var endIndex: int

# Useful for functions
var childs: Array[Token]
var bodyStartIndex: int
var bodyEndIndex: int

#const handledTypes: PackedStringArray = ["float", "int", "vec2", "vec3",]
const handledoperators: PackedStringArray = ["=", "+", "-", "*", "/", "%"]

# Initialize the token using the line string
func _init(line: String, lineStartIndex: int, lineEndIndex: int) -> void:
	originalLine = line
	
	startIndex = lineStartIndex
	endIndex = lineEndIndex
	
	if line.is_empty():
		return
	
	# Lines to ignore
	if line.begins_with("group_uniforms"):
		return
	
	if line[0] == "#":
		var editedLine = line.lstrip("#").strip_edges(true, false)
		var splittedLine: PackedStringArray = editedLine.split(" ")
		
		type = splittedLine[0]
		if splittedLine.size() > 1:
			tokenName = splittedLine[1]
		if splittedLine.size() > 2:
			tokenValue = splittedLine[2]
		
		if type == "define":
			tokenType = TokenTypes.DEFINE_MACRO
		elif type == "include":
			tokenType = TokenTypes.INCLUDE_MACRO
		
		return
	
	# Note: The order is important, the variable parser consider a function like a variable
	if "(" in line and ")" in line and "{" in line:
		tokenType = TokenTypes.FUNCTION
		
		tokenName = line.split("(")[0].split(" ")[-1]
		
		#startIndex = lineStartIndex # Already done
		endIndex = -1 # Replace
		
		bodyStartIndex = lineStartIndex + line.find("{") + 1
		bodyEndIndex = -1
		
		return
	
	#TODO: Maybe replace "\t" with " "
	var splittedLine: PackedStringArray = line.split(" ")
	if line.begins_with("uniform"):
		tokenType = TokenTypes.UNIFORM
		tokenName = splittedLine[2].rstrip(";")
		type = splittedLine[1]
		return
	
	#TODO: VARIABLE
	if splittedLine.size() > 1 and splittedLine[1][0] not in handledoperators:
		tokenType = TokenTypes.VARIABLE
		tokenName = splittedLine[1].rstrip(";")
		type = splittedLine[0]
		return
