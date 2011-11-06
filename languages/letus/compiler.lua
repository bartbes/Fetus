#!/usr/bin/env lua

local tree
local environment = {}
local variables = 0
environment[" "] = environment

local function addVariable()
	variables = variables + 1
	return variables
end

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
	fcall = 0x20,
	fcalls = 0x21,
	tcall = 0x21,
	tcalls = 0x22,
	["return"] = 0x25,
}

local functionList = {
	putn = 0xffff,
	putc = 0xfffe,
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

local function lexicalscope(env, key, value)
	if rawget(env, key) then
		rawset(env, key, value)
	elseif not env[key] then
		rawset(env, key, value)
	else
		env[" "][key] = value
	end
end

local function createEnv()
	return setmetatable({[" "] = environment}, {__index = environment, __newindex = lexicalscope})
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
	if environment[command] then
		local var1, var2 = oneToTwo(environment[command])
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

local function set(output, var)
	return output:write(
		string.char(opcodeList.set, oneToTwo(var)) ..
		string.char(opcodeList.pop, 0x00, 0x00))
end

special["set!"] = function(output, node)
	assert(#node < 4, "Can't assign multiple values to a variable")
	assert(#node > 1, "Need a variable name and a value")
	assert(#node > 2, "Need a value")
	local varname = node[2]
	assert(not tonumber(varname), "Can't assign a value to a number")
	assert(not varname:match("%b()"), "Can't assign a value to an S-expression")

	local value
	compileNodeOrLiteral(output, node[3])
	local var = environment[varname] or addVariable()
	environment[varname] = var
	set(output, var)
end

function special.lambda(output, node)
	-- store our curent position
	local pos = output:getPos()

	--create an environment for ourselves
	environment = createEnv()

	--parse the argument list
	local args = table.remove(node, 2)
	for i = #args, 1, -1 do
		rawset(environment, args[i], addVariable())
		set(output, environment[args[i]])
	end

	--compile as if it were a begin statement
	node[1] = "begin"
	compileNode(output, node)

	--add a return statement
	opcodes.call(output, "return")

	--restore the environment
	environment = environment[" "]

	--at the start, write a jump to the end
	--so it doesn't get run on definition
	output:writeAt(pos, string.char(
		opcodeList.put, 0x00, 0x01,
		opcodeList.goto, oneToTwo(output:getPos()+2)))

	--register it in the header
	local value = makeHeader("function", pos+2)

	--return the assigned id
	opcodes.push(output, value)
end

special["if"] = function(output, node)
	assert(#node > 2, "If requires at least 2 arguments")
	assert(#node < 5, "If handles no more than 3 arguments")
	--compile the condition first
	compileNode(output, node[2])
	--prepare our jump
	local pos = output:getPos()
	output:write(string.char(opcodeList["not"], 0x00, 0x00))
	--compile our true condition
	compileNodeOrLiteral(output, node[3])
	--and if we have one, our false condition
	local falsecond = output:getPos()
	if #node == 4 then
		output:write(string.char(opcodeList.put, 0x00, 0x01))
		falsecond = output:getPos()+3
		compileNodeOrLiteral(output, node[4])
		--put a jump to the end after the true
		output:writeAt(falsecond-3, string.char(opcodeList.goto, oneToTwo(output:getPos()+4)))
	end
	--rewrite the jump with the now-determined location
	output:writeAt(pos+1, string.char(opcodeList.goto, oneToTwo(falsecond+1)))
end


function special.let(output, node)
	assert(#node > 2, "let needs at least 3 arguments")
	-- do our scoping
	local newenv = createEnv()

	-- let's handle the real let syntax
	-- the first argument is a list of pairs
	local lets = table.remove(node, 2)
	for _, pair in ipairs(lets) do
		compileNodeOrLiteral(output, pair[2])
		rawset(newenv, pair[1], addVariable())
		set(output, newenv[pair[1]])
	end

	--actually switch the environments
	environment = newenv

	-- compile the rest as if it was a begin
	node[1] = "begin"
	compileNode(output, node)
	environment = environment[" "]
end

function special.comment()
end

function compileLiteral(output, literal)
	if tonumber(literal) then
		return opcodes.push(output, tonumber(literal))
	end
	if environment[literal] then
		return opcodes.get(output, environment[literal])
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
		compileNodeOrLiteral(output, node[i])
	end
	opcodes.call(output, node[1])
end

function compileNodeOrLiteral(output, node)
	if type(node) == "table" then
		return compileNode(output, node)
	else
		return compileLiteral(output, node)
	end
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

	local contents = i:read("*l")
	if contents:sub(1, 2) == "#!" then
		contents = ""
	end
	contents = contents .. i:read("*a")
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
