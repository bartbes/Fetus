#!/usr/bin/env lua

function unescape(str)
	str = str:gsub("\\(%d%d%d)", string.char)
	return str:gsub("\\(.)", function(x)
		local res = loadstring([[return '\]] .. x .. [[']])()
		return res
	end)
end

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
	ctxt = 0x19,
	ctxts = 0x1a,
	ctxtn = 0x1b,
	fcall = 0x1d,
	fcalls = 0x1e,
	["return"] = 0x1f,
}

if not arg then
	print("Must be called from the command line")
	return 1
end
if #arg < 1 then
	print("Usage: " .. arg[0] .. " <infile> [outfile]")
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
local output = ""
local command, args, str
local strings = {}
for line in i:lines() do
	command, args = line:match("^(%a+) (%w%w%w%w)$")
	if command and args and commandlist[command] then
		output = output .. string.char(commandlist[command])
		output = output .. string.char(tonumber(args:sub(1, 2), 16))
		output = output .. string.char(tonumber(args:sub(3, 4), 16))
	end
	str = line:match("^\"(.+)\"$")
	if str then
		table.insert(strings, (unescape(str)))
	end
end

local header = string.char(0xff, 0x00, 0x00)
for i, v in ipairs(strings) do
	local i = 0
	local oc = 0
	for c in v:gmatch(".") do
		if i % 2 == 0 then
			header = header .. string.char(0xf2)
		end
		i = i + 1
		header = header .. c
	end
	if i % 2 ~= 0 then
		header = header .. string.char(0)
	else
		header = header .. string.char(0xf2, 0x0, 0x0)
	end
end
header = header .. string.char(0xf1, 0x00, 0x00)

o:write(header .. output)

i:close()
o:close()
