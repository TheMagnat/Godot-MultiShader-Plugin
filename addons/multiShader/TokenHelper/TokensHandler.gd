class_name TokensHandler

var originalShader: Shader

var shaderMacros: Dictionary

var tokenList: Array[Token]
var depthLevel: int

# This store for each shaders the encountered conflicts
static var conflictsPerShader := {}

### Id handling section

# Token handler id, refer to the local scope id, will be used if conflicts are found
static var idPerShader := {}

#const idCharacters: String = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
#const idSize: int = 6

static var count: int = 0
static func resetStatics():
	count = 0
	conflictsPerShader.clear()

func _initializeShaderStatics():
	if originalShader not in conflictsPerShader:
		conflictsPerShader[originalShader] = PackedStringArray()
		idPerShader[originalShader] = "%d" % count
		
		count += 1

func _init(originalShaderParam: Shader, tokenListParam: Array[Token], shaderMacrosParam: Dictionary, depthLevelParam: int = 0) -> void:
	originalShader = originalShaderParam
	
	shaderMacros = shaderMacrosParam
	
	tokenList = tokenListParam
	depthLevel = depthLevelParam
	
	_initializeShaderStatics()

func getString(token: Token, depthLevel: int, localScope: Array[Token], globalScope: Array[Token]) -> String:
	"""
	Convert a token to a String.
	This function will also update conflicts array.
	"""
	if token.tokenType != Token.TokenTypes.EMPTY:
		
		for local in localScope:
			if token.tokenName != local.tokenName:
				continue
			
			# Here, a new token have the same name as a local token. Applying logic accordingly
			
			if token.type == local.type:
				# Here, the local and new token have same name and type, we assume they are the same
				return ""
			
			# Here we have a conflict, store it
			conflictsPerShader[originalShader].push_back(token.tokenName)
			
			# TODO: Maybe update the token
	
	if token.tokenType == Token.TokenTypes.DEFINE_MACRO:
		if token.tokenName not in shaderMacros:
			shaderMacros[token.tokenName] = token.tokenValue
	
	var res = "\t".repeat(depthLevel) + token.originalLine + "\n"
	
	# Function logic
	if token.tokenType == Token.TokenTypes.FUNCTION:
		var childsTokensHandler := TokensHandler.new(originalShader, token.childs, shaderMacros, depthLevel + 1)
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
	for conflict in conflictsPerShader[originalShader]:
		# Here there is conflicts, rename the encountered conflicts
		res = res.replace(conflict, "%s_%s" % [conflict, idPerShader[originalShader]])
	
	return res
