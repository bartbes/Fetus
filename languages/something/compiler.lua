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
filename = arg[1] == "-" and "stdin" or arg[1]

if not arg[2] then arg[2] = "a.ftsb" end
local output = arg[2] == "-" and io.stdout or io.open(arg[2], "w")
if not output then
	print(("Could not open output file \"%s\"."):format(arg[2]))
	os.exit(1)
end

local tree = {}

local function parse_to_tree(tree, text)
	local start = 0
	local depth = 0
	local pos = 0
	local outtext = ""
	local num = 0
	for char in text:gmatch(".") do
		pos = pos + 1
		if char == "(" then
			depth = depth + 1
			if depth == 1 then
				start = pos
			end
		elseif char == ")" then
			depth = depth - 1
			if depth == 0 then
				table.insert(tree, text:sub(start+1, pos-1))
				num = num + 1
				outtext = outtext .. ("[%d]"):format(num)
			end
		elseif depth == 0 then
			outtext = outtext .. char
		end
	end
	return outtext
end

local function parsetree(tree)
	for i, v in ipairs(tree) do
		local tempnode = {}
		tempnode.text = parse_to_tree(tempnode, v)
		parsetree(tempnode)
		tree[i] = tempnode
	end
end

function parse()
	local t = input:read("*a")
	parse_to_tree(tree, t)
	parsetree(tree)
end

parse()

local function dumptable(t, depth)
	local tabs = ("  "):rep(depth)
	for i, v in ipairs(t) do
		if type(v) == "table" then
			output:write(tabs .. v.text .. "\n")
			dumptable(v, depth+1)
		else
			output:write(tabs .. tostring(v) .. "\n")
		end
	end
end

dumptable(tree, 0)
