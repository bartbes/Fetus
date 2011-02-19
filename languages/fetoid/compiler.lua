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
local num_vars = 0
local code = {}
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

local function parse(expression)
	local results = {expression:match("^(%d+)$")}
	if #results == 1 then
		commands.put(results[1])
		return
	end
	results = {expression:match("^(%w+)$")}
	if #results == 1 then
		commands.get(results[1])
		return
	end
	results = {expression:match("^(%w+)%s*=%s*(.+)$")}
	if #results == 2 then
		if not vars[results[1]] then
			vars[results[1]] = num_vars
			num_vars = num_vars + 1
		end
		parse(results[2])
		commands.set(results[1])
		return
	end
	results = {expression:match("^putn (.+)$")}
	if #results == 1 then
		parse(results[1])
		commands.call(0xffff)
		return
	end
	compile_error("\"%s\" is an invalid expression.", expression)
end

for line in input:lines() do
	linenum = linenum + 1
	parse(line)
end

for i, v in ipairs(code) do
	code[i] = string.char(v)
end
output:write(table.concat(code, ""))
input:close() output:close()
