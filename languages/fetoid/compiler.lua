if #arg < 2 then
	print(("Usage: %s <input> <output>"):format(arg[0]))
	os.exit(1)
end

local linenum = 0
local filename

function compile_error(err, ...)
	print(("%s:%d: Compilation error: %s"):format(filename, linenum, err:format(...)))
	os.exit(2)
end

local input = io.open(arg[1], "r")
if not input then
	print(("Could not open input file \"%s\"."):format(arg[1]))
end
filename = arg[1]

local output = io.open(arg[2], "w")
if not output then
	print(("Could not open output file \"%s\"."):format(arg[2]))
end

local vars = {}
local num_vars = 1
local stack_depth = 0
local code = {}
local line_ip = 0
local commands = {}

local function numtoarg(num)
	return math.floor(num/256), num%256
end

local function addcode(t, ...)
	if tonumber(t) then
		t = {t, ...}
	end
	for i, v in ipairs(t) do
		table.insert(code, v)
	end
end

function commands.put(num)
	return addcode(0x03, numtoarg(num))
end

function commands.get(var)
	return addcode(0x01, numtoarg(vars[var]))
end

function commands.set(var)
	return addcode(0x02, numtoarg(vars[var]))
end

function commands.call(func)
	return addcode(0x05, numtoarg(func))
end

function commands.add()
	return addcode(0x0a, 0x00, 0x00)
end

function commands.sub()
	return addcode(0x0b, 0x00, 0x00)
end

local function parse_brackets(exp)
end

local function parse(expression)
	if expression:match("^%s*%.%s*$") then
		table.insert(code, line_ip, 0x00)
		table.insert(code, line_ip, 0x00)
		table.insert(code, line_ip, 0x02)
		addcode(0x01, 0x00, 0x00)
		return
	end
	local results = {expression:match("^%s*(%d+)%s*$")}
	if #results == 1 then
		commands.put(results[1])
		stack_depth = stack_depth + 1
		return
	end
	results = {expression:match("^%s*(%w+)%s*$")}
	if #results == 1 then
		commands.get(results[1])
		stack_depth = stack_depth + 1
		return
	end
	results = {expression:match("^%s*(%w+)%s*=%s*(.+)%s*$")}
	if #results == 2 then
		if not vars[results[1]] then
			vars[results[1]] = num_vars
			num_vars = num_vars + 1
		end
		parse(results[2])
		commands.set(results[1])
		return
	end
	results = {expression:match("^%s*putn%s+(.+)$")}
	if #results == 1 then
		parse(results[1])
		commands.call(0xffff)
		return
	end
	results = {expression:match("^%s*(.-)%s*%+%s*(.+)%s*$")}
	if #results == 2 then
		parse(results[1])
		parse(results[2])
		commands.add()
		stack_depth = stack_depth - 1
		return
	end
	results = {expression:match("^%s*(.-)%s*%-%s*(.+)%s*$")}
	if #results == 2 then
		parse(results[1])
		parse(results[2])
		commands.sub()
		stack_depth = stack_depth - 1
		return
	end
	compile_error("\"%s\" is an invalid expression.", expression)
end

for line in input:lines() do
	linenum = linenum + 1
	parse(line)
	line_ip = #code+1
end

for i, v in ipairs(code) do
	code[i] = string.char(v)
end
output:write(table.concat(code, ""))
input:close() output:close()
