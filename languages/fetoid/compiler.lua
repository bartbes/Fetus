if #arg < 2 then
	print(("Usage: %s <input> <output>"):format(arg[0]))
	os.exit(1)
end

local linenum = 0
local filename

function compile_error(err)
	print(("%s:%d: Compilation error: %s"):format(filename, linenum, err))
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

for line in input:lines() do
	linenum = linenum + 1
	local result = line:match("^declare (.+)$")
	if result then
		for name in result:gmatch("%w+") do
			if vars[name] then
				compile_error(("%s redeclared!"):format(name))
			end
			vars[name] = #vars
		end
	end
end
