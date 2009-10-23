#!/usr/bin/env lua

commandlist = {
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
}

if not arg then
	print("Must be called from the command line")
	return 1
end
if #arg < 2 then
	print("Usage: " .. arg[0] .. " <infile> <outfile>")
	return 1
end
local i = arg[1] == "-" and io.stdin or io.open(arg[1])
if not i then
	print("Could not open file " .. arg[1])
	return 1
end
local o = arg[2] == "-" and io.stdout or io.open(arg[2], "w")
if not o then
	print("Could not open file " .. arg[2])
	return 1
end
local command, args
for line in i:lines() do
	command, args = line:match("^(%a+) (%w%w%w%w)$")
	if command and args and commandlist[command] then
		o:write(string.char(commandlist[command]))
		o:write(string.char(tonumber(args:sub(1, 2), 16)))
		o:write(string.char(tonumber(args:sub(3, 4), 16)))
	end
end
i:close()
o:close()
