#!/usr/bin/env lua

local tree
local variables = {}

local opcodeList = {
	get = 0x01,
	set = 0x02,
	put = 0x03,
	pop = 0x04,
	call = 0x05,
	clear = 0x06,
	getp = 0x07,
	goto = 0x08,
	gotos = 0x09,
	add = 0x0a,
	sub = 0x0b,
	mult = 0x0c,
	div = 0x0d,
	pow = 0x0e,
	root = 0x0f,
	mod = 0x10,
	eq = 0x11,
	lt = 0x12,
	gt = 0x13,
	["not"] = 0x14,
	pos = 0x15,
	ascii = 0x16,
	num = 0x17,
	setp = 0x18,
	ctxt = 0x19,
	ctxts = 0x1a,
	ctxtn = 0x1b,
	fcall = 0x1d,
	fcalls = 0x1e,
	["return"] = 0x1f,
}

local functionList = {
	putn = 0xffff,
}

local commandList = {
	add = opcodeList.add,
	["+"] = opcodeList.add,
	sub = opcodeList.sub,
	["-"] = opcodeList.sub,
	mult = opcodeList.mult,
	["*"] = opcodeList.mult,
	div = opcodeList.div,
	["/"] = opcodeList.div,
	pow = opcodeList.pow,
	root = opcodeList.root,
	mod = opcodeList.mod,
	["%"] = opcodeList.mod,
	eq = opcodeList.eq,
	["="] = opcodeList.eq,
	["eq?"] = opcodeList.eq,
	lt = opcodeList.lt,
	["<"] = opcodeList.lt,
	gt = opcodeList.gt,
	[">"] = opcodeList.gt,
	["not"] = opcodeList["not"],
	["return"] = opcodeList["return"],
}

local function node(command, args)
	assert(command, "Invalid node")
	if not args then
		return command
	end
	return {command, unpack(args)}
end

local function oneToTwo(value)
	return math.floor(value/256), value%256
end

local makeHeader
local getHeader

do
	local str
	local functions = 0

	function makeHeader(key, value)
		if key == "start" then
			str = string.char(0xff, 0xff, 0xff)
			return nil
		end
		if key == "end" then
			str = str .. string.char(0xf1, 0x00, 0x00)
			return nil
		end
		if key == "function" then
			functions = functions + 1
			str = str .. string.char(0xf0, oneToTwo(value))
			return functions
		end
	end

	function getHeader()
		return str
	end
end

local opcodes = {}
local special = {}

function opcodes.push(output, value)
	return output:write(string.char(opcodeList.put, oneToTwo(value)))
end

function opcodes.get(output, var)
	return output:write(string.char(opcodeList.get, oneToTwo(var)))
end

function opcodes.call(output, command)
	if variables[command] then
		local var1, var2 = oneToTwo(variables[command])
		return output:write(string.char(
			opcodeList.get, var1, var2,
			opcodeList.fcalls, 0x00, 0x00))
	elseif opcodes[command] then
		return opcodes[command](output)
	elseif commandList[command] then
		return output:write(string.char(commandList[command], 0, 0))
	elseif functionList[command] then
		local num = functionList[command]
		return output:write(string.char(opcodeList.call, oneToTwo(num)))
	end
	error("Invalid call to " .. command)
end

function opcodes.begin()
end

special["set!"] = function(output, node)
	assert(#node < 4, "Can't assign multiple values to a variable")
	assert(#node > 1, "Need a variable name and a value")
	assert(#node > 2, "Need a value")
	local varname = node[2]
	assert(not tonumber(varname), "Can't assign a value to a number")
	assert(not varname:match("%b()"), "Can't assign a value to an S-expression")

	local value
	if type(node[3]) == "table" then
		compileNode(output, node[3])
	else
		opcodes.push(output, parseLiteral(node[3]))
	end
	local var = variables[varname] or #variables+1
	variables[varname] = var
	output:write(string.char(opcodeList.set, oneToTwo(var)))
end

function special.lambda(output, node)
	local pos = output:getPos()
	node[1] = "begin"
	compileNode(output, node)
	output:writeAt(pos, string.char(
		opcodeList.put, 0x00, 0x01,
		opcodeList.goto, oneToTwo(output:getPos()+2)))
	local value = makeHeader("function", pos+2)
	opcodes.push(output, value)
end

function compileLiteral(output, literal)
	if tonumber(literal) then
		return opcodes.push(output, tonumber(literal))
	end
	if variables[literal] then
		return opcodes.get(output, variables[literal])
	end
	error(("Unknown variable %s"):format(literal))
end

function parseCode(code)
	local sexpr = ("begin %s"):format(code)
	tree = parseSexpr(sexpr)
end

function parseSexpr(sexpr)
	local command, args = nil, {}
	local rest = sexpr
	while #rest > 0 do
		local val, _rest = rest:match("^(%b())%s*(.*)$")
		if val then
			val = parseSexpr(val:sub(2, -2))
		else
			val, _rest = rest:match("^(%S+)%s*(.*)$")
		end
		table.insert(args, val)
		rest = _rest
	end
	command = table.remove(args, 1)
	assert(command)

	return node(command, args)
end

local function printTree_(output, node, depth)
	local prefix = ""
	if node.name then
		prefix = ("  "):rep(depth) .. node.name .. ": "
	end
	output:write(prefix)
	local name = "(Tree-%c)"
	local counter = 0
	local next = {}
	for i, v in ipairs(node) do
		if type(v) == "table" then
			v.name = name:format(97+counter)
			counter = counter + 1
			output:write(v.name)
			table.insert(next, v)
		else
			output:write(v)
		end
		output:write(" ")
	end
	output:write("\n")
	for i, v in ipairs(next) do
		printTree_(output, v, depth+1)
	end
end

function printTree(output)
	return printTree_(output, tree, 0)
end

function compileNode(output, node)
	if special[node[1]] then
		return special[node[1]](output, node)
	end
	for i = 2, #node do
		if type(node[i]) == "table" then
			compileNode(output, node[i])
		else
			compileLiteral(output, node[i])
		end
	end
	opcodes.call(output, node[1])
end

function main(argv0, arg)
	if not arg then
		print("Must be called from the command line")
		return 1
	end

	if #arg < 1 then
		print("Usage: " .. argv0 .. " <infile> [outfile]")
		return 1
	end

	local i = arg[1] == "-" and io.stdin or io.open(arg[1])
	if not i then
		print("Could not open file " .. arg[1])
		return 1
	end

	if not arg[2] then arg[2] = "a.ftsb" end
	local o = arg[2] == "-" and io.stdout or io.open(arg[2], "wb")
	if not o then
		print("Could not open file " .. arg[2])
		return 1
	end

	local contents = i:read("*a")
	parseCode(contents)
	
	output = {
		str = "",
		write = function(self, text)
			self.str = self.str .. text
		end,
		writeAt = function(self, pos, text)
			self.str = self.str:sub(1, pos*3) .. text .. self.str:sub(pos*3+1, -1)
		end,
		getPos = function(self)
			return #self.str/3
		end,
	}

	makeHeader("start")
	compileNode(output, tree)
	makeHeader("end")

	o:write(getHeader())
	o:write(output.str)

--	printTree(o)

	i:close()
	o:close()
end

main(arg[0], {...})
