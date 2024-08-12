class_name TokensHandler

const typeCantConflict: Array[Token.TokenTypes] = [
	Token.TokenTypes.EMPTY,
	#Token.TokenTypes.FUNCTION,
	#Token.TokenTypes.VARIABLE,
	#Token.TokenTypes.UNIFORM,
	Token.TokenTypes.FOR_STATEMENT,
	Token.TokenTypes.IF_STATEMENT,
	#Token.TokenTypes.DEFINE_MACRO,
	#Token.TokenTypes.INCLUDE_MACRO,
	#Token.TokenTypes.DIRECTIVE
]

# Keep a reference to the MultiShaderMaterial to use the cache variables
var multiShaderMaterial: MultiShaderMaterial

var originalShader: Shader

var shaderMacros: Dictionary

var tokenList: Array[Token]
var depthLevel: int

func _initializeShaderCache():
	if originalShader not in multiShaderMaterial._conflictsPerShader:
		multiShaderMaterial._conflictsPerShader[originalShader] = PackedStringArray()
		multiShaderMaterial._idPerShader[originalShader] = "%d" % multiShaderMaterial._count
		
		multiShaderMaterial._count += 1

func _init(multiShaderMaterialParam: MultiShaderMaterial, originalShaderParam: Shader, tokenListParam: Array[Token], shaderMacrosParam: Dictionary, depthLevelParam: int = 0) -> void:
	multiShaderMaterial = multiShaderMaterialParam
	
	originalShader = originalShaderParam
	
	shaderMacros = shaderMacrosParam
	
	tokenList = tokenListParam
	depthLevel = depthLevelParam
	
	_initializeShaderCache()

var inForLogic: bool = false
func getString(token: Token, depthLevel: int, localScope: Array[Token], globalScope: Array[Token]) -> String:
	"""
	Convert a token to a String.
	This function will also update conflicts array.
	"""
	if token.tokenType not in typeCantConflict:
		
		for local in localScope:
			if token.tokenName != local.tokenName:
				continue
			
			# Here, a new token have the same name as a local token. Applying logic accordingly
			
			if token.type == local.type:
				# Here, the local and new token have same name and type, we assume they are the same
				return ""
			
			# Here we have a conflict, store it
			multiShaderMaterial._conflictsPerShader[originalShader].push_back(token.tokenName)
			
			# TODO: Maybe update the token
	
	
	# If for, activate the for logic.
	# The for logic will skip end of line untile the end of the for is reached.
	# It also skip the "tab" after the first token
	var startForLogic = inForLogic
	if token.tokenType == Token.TokenTypes.FOR_STATEMENT:
		inForLogic = true
	
	if inForLogic:
		if ")" in token.originalLine:
			inForLogic = false
	
	if token.tokenType == Token.TokenTypes.DEFINE_MACRO:
		if token.tokenName not in shaderMacros:
			shaderMacros[token.tokenName] = token.tokenValue
	
	var res = "\t".repeat(depthLevel * int(not startForLogic)) + token.originalLine + ("\n" if not inForLogic else " ")
	
	# Scope logic (can be function or if and for for example)
	if token.childs:
		var childsTokensHandler := TokensHandler.new(multiShaderMaterial, originalShader, token.childs, shaderMacros, depthLevel + 1)
		return res + \
			childsTokensHandler.tokenListToString() + \
			"\t".repeat(depthLevel) + "}\n"
	
	# Define macro logic
	if token.tokenType == Token.TokenTypes.DEFINE_MACRO:
		return res.replace(token.tokenValue, str(shaderMacros[token.tokenName]))
	
	# Import macro logic
	if token.tokenType == Token.TokenTypes.INCLUDE_MACRO:
		# Verify if the value is not local
		if not token.tokenName.begins_with("\"res:"):
			var noQuotePath: String = token.tokenName.lstrip("\"").rstrip("\"")
			return res.replace(token.tokenName, "\"%s/%s\"" % [originalShader.resource_path.get_base_dir(), noQuotePath])
	
	return res


func _tokenListToString(tokenList: Array[Token], depthLevel: int, localScope: Array[Token], globalScope: Array[Token]) -> String:
	var res: String = ""
	for token in tokenList:
		res += getString(token, depthLevel, localScope, globalScope)
	
	#Verify token to watch
	
	return res

func tokenListToString(tokenToWatch: Array[Token] = []) -> String:
	var res: String = _tokenListToString(tokenList, depthLevel, tokenToWatch, [])
	
	# Handle conflicts here
	for conflict in multiShaderMaterial._conflictsPerShader[originalShader]:
		# Here there is conflicts, rename the encountered conflicts
		res = res.replace(conflict, "%s_%s" % [conflict, multiShaderMaterial._idPerShader[originalShader]])
	
	return res
