#!/usr/bin/env lua

commandlist = {
	[0x01] = "get",
	[0x02] = "set",
	[0x03] = "put",
	[0x04] = "pop",
	[0x05] = "call",
	[0x06] = "clear",
	[0x07] = "getp",
	[0x08] = "goto",
	[0x09] = "gotos",
	[0x0a] = "add",
	[0x0b] = "sub",
	[0x0c] = "mult",
	[0x0d] = "div",
	[0x0e] = "pow",
	[0x0f] = "root",
	[0x10] = "mod",
	[0x11] = "eq",
	[0x12] = "lt",
	[0x13] = "gt",
	[0x14] = "not",
	[0x15] = "pos",
	[0x16] = "ascii",
	[0x17] = "num",
	[0x18] = "setp",
}

if not arg then
	print("Must be called from the command line")
	return 1
end
if #arg < 1 then
	print("Usage: " .. arg[0] .. " <infile>")
	return 1
end
local i = arg[1] == "-" and io.stdin or io.open(arg[1])
if not i then
	print("Could not open file " .. arg[i])
	return 1
end
local line = i:read(3)
while line do
	io.write(commandlist[string.byte(line:sub(1, 1))] .. " ")
	io.write(string.format("%02x", string.byte(line:sub(2, 2))))
	io.write(string.format("%02x", string.byte(line:sub(3, 3))) .. "\n")
	line = i:read(3)
end
i:close()
