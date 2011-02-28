#!/usr/bin/env lua

if #arg < 1 then
	print(("Usage: %s <input> [output]"):format(arg[0]))
	os.exit(1)
end

local linenum = 0
local filename

function compile_error(err, ...)
	print(("%s:%d: Compilation error: %s"):format(filename, linenum, err:format(...)))
	os.exit(2)
end

local input = arg[1] == "-" and io.stdin or io.open(arg[1], "r")
if not input then
	print(("Could not open input file \"%s\"."):format(arg[1]))
	os.exit(1)
end
filename = arg[1] == "-" and stdin or arg[1]

if not arg[2] then arg[2] = "a.ftsb" end
local output = arg[2] == "-" and io.stdout or io.open(arg[2], "w")
if not output then
	print(("Could not open output file \"%s\"."):format(arg[2]))
	os.exit(1)
end

local vars = {}
local num_vars = 1
local stack_depth = 0
local code = {}
local line_ip = 0
local commands = {}
local function_start = 0
local ifs = {}
local whiles = {}

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
	if not vars[var] then compile_error("Variable '%s' doesn't exist.", var) end
	return addcode(0x01, numtoarg(vars[var]))
end

function commands.set(var)
	if not vars[var] then compile_error("Variable '%s' doesn't exist.", var) end
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

function commands.mult()
	return addcode(0x0c, 0x00, 0x00)
end

function commands.div()
	return addcode(0x0d, 0x00, 0x00)
end

function commands.pow()
	return addcode(0x0e, 0x00, 0x00)
end

function commands.root()
	return addcode(0x0f, 0x00, 0x00)
end

function commands.mod()
	return addcode(0x10, 0x00, 0x00)
end

function commands.eq()
	return addcode(0x11, 0x00, 0x00)
end

function commands.lt()
	return addcode(0x12, 0x00, 0x00)
end

function commands.gt()
	return addcode(0x13, 0x00, 0x00)
end

commands["not"] = function()
	return addcode(0x14, 0x00, 0x00)
end

function commands.yield()
	return addcode(0x1a, 0x00, 0x00)
end

local function parse(expression)
	if expression:match("^%s*%.%s*$") then
		table.insert(code, line_ip, 0x00)
		table.insert(code, line_ip, 0x00)
		table.insert(code, line_ip, 0x02)
		addcode(0x01, 0x00, 0x00)
		return
	end
	if expression:match("^%s*function%s*$") then
		function_start = #code+1
		addcode(0x06, 0x00, 0x00)
		stack_depth = 0
		return
	end
	if expression:match("^%s*endfunc%s*$") then
		local pos = #code/3+5
		table.insert(code, function_start, pos%256)
		table.insert(code, function_start, math.floor(pos/256))
		table.insert(code, function_start, 0x08)
		table.insert(code, function_start, 0x01)
		table.insert(code, function_start, 0x00)
		table.insert(code, function_start, 0x03)
		local start = (function_start-1)/3+2
		addcode(0x06, 0x00, 0x00,
			0x03, 0x00, 0x01,
			0x08, 0x00, 0x00,
			0x03, math.floor(start/256), start%256,
			0x03, math.floor(pos/256), pos%256,
			0x05, 0x00, 0x0d)
		stack_depth = 0
		return
	end
	local results = {expression:match("^%s*if%s+(.-)%s*$")}
	if #results == 1 then
		parse(results[1])
		table.insert(ifs, #code+1)
		stack_depth = 0
		return
	end
	if expression:match("^%s*endif%s*$") then
		local pos = #code/3+2
		local start = table.remove(ifs)
		table.insert(code, start, pos%256)
		table.insert(code, start, math.floor(pos/256))
		table.insert(code, start, 0x08)
		table.insert(code, start, 0x00)
		table.insert(code, start, 0x00)
		table.insert(code, start, 0x14)
		return
	end
	if expression:match("^%s*do%s*$") then
		table.insert(whiles, #code+1)
		return
	end
	local results = {expression:match("^%s*while%s+(.-)%s*$")}
	if #results == 1 then
		local start = table.remove(whiles)/3
		parse(results[1])
		addcode(0x08, math.floor(start/256), start%256)
		stack_depth = 0
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
	if #results == 2 and not results[2]:match("^=") then
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
	results = {expression:match("^%s*(.-)%s*==%s*(.+)%s*$")}
	if #results == 2 then
		parse(results[1])
		parse(results[2])
		commands.eq()
		stack_depth = stack_depth - 1
		return
	end
	results = {expression:match("^%s*(.-)%s*!=%s*(.+)%s*$")}
	if #results == 2 then
		parse(results[1])
		parse(results[2])
		commands.eq()
		commands["not"]()
		stack_depth = stack_depth - 1
		return
	end
	results = {expression:match("^%s*(.-)%s*>=%s*(.+)%s*$")}
	if #results == 2 then
		parse(results[1])
		parse(results[2])
		commands.lt()
		commands["not"]()
		stack_depth = stack_depth - 1
		return
	end
	results = {expression:match("^%s*(.-)%s*<=%s*(.+)%s*$")}
	if #results == 2 then
		parse(results[1])
		parse(results[2])
		commands.gt()
		commands["not"]()
		stack_depth = stack_depth - 1
		return
	end
	results = {expression:match("^%s*(.-)%s*>%s*(.+)%s*$")}
	if #results == 2 then
		parse(results[1])
		parse(results[2])
		commands.gt()
		stack_depth = stack_depth - 1
		return
	end
	results = {expression:match("^%s*(.-)%s*<%s*(.+)%s*$")}
	if #results == 2 then
		parse(results[1])
		parse(results[2])
		commands.lt()
		stack_depth = stack_depth - 1
		return
	end
	results = {expression:match("^%s*!(.+)%s*$")}
	if #results == 1 then
		parse(results[1])
		commands["not"]()
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
	results = {expression:match("^%s*(.-)%s*%+%s*(.+)%s*$")}
	if #results == 2 then
		parse(results[1])
		parse(results[2])
		commands.add()
		stack_depth = stack_depth - 1
		return
	end
	results = {expression:match("^%s*(.-)%s*%%%s*(.+)%s*$")}
	if #results == 2 then
		parse(results[1])
		parse(results[2])
		commands.mod()
		stack_depth = stack_depth - 1
		return
	end
	results = {expression:match("^%s*(.-)%s*/%s*(.+)%s*$")}
	if #results == 2 then
		parse(results[1])
		parse(results[2])
		commands.div()
		stack_depth = stack_depth - 1
		return
	end
	results = {expression:match("^%s*(.-)%s*%*%s*(.+)%s*$")}
	if #results == 2 then
		parse(results[1])
		parse(results[2])
		commands.mult()
		stack_depth = stack_depth - 1
		return
	end
	results = {expression:match("^%s*(.-)%s*^%s*(.+)%s*$")}
	if #results == 2 then
		parse(results[1])
		parse(results[2])
		commands.pow()
		stack_depth = stack_depth - 1
		return
	end
	results = {expression:match("^%s*yield%s+(.+)%s*$")}
	if #results == 1 then
		parse(results[1])
		commands.yield()
		return
	end
	if expression:match("^%s*$") then
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
