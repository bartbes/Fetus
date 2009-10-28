#!/usr/bin/env lua

function unescape(str)
	str = str:gsub("\\(%d%d%d)", string.char)
	return str:gsub("\\(.)", function(x)
		local res = loadstring([[return '\]] .. x .. [[']])()
		return res
	end)
end

function parsestrings(str)
	str = unescape(str)
	local r = ""
	for i = 1, #str do
		r = r .. string.format("put %04x\n", string.byte(str:sub(i, i)))
	end
	r = r .. "put 0000\n"
	return r
end

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
	print("Could not open file " .. arg[i])
	return 1
end
if not arg[2] then arg[2] = "a.ftsp" end
local o = arg[2] == "-" and io.stdout or io.open(arg[2], "w")
local content = i:read("*a")
content = content:gsub("\"(.-)\"", parsestrings)
if content:sub(1, 2) == "#!" then
	content = content:match("#!.-\n(.*)")
end
local labels = {}
local vars = {}
local count = 0
local output = ""
local labelinserts = {}
local m, addr
for line in content:gmatch("(.-)\n") do
	if line:match("^(%a+) (%w%w%w%w)$") then
		count = count + 1
		output = output .. line .. "\n"
	end
	m = line:match("^:(%a+)$")
	if m then
		labels[m] = count
	end
	m = line:match("^goto :(%a+)$")
	if m then
		output = output .. string.format("goto %%s\n")
		table.insert(labelinserts, m)
		count = count + 1
	end
	m = line:match("^put :(%a+)$")
	if m then
		output = output .. string.format("put %%s\n")
		table.insert(labelinserts, m)
		count = count + 1
	end
	m, addr = line:match("^$(%a+) (%w%w%w%w)$")
	if m then
		vars[m] = tonumber(addr, 16)
	end
	m, addr = line:match("^(%a+) $(%a+)$")
	if m then
		count = count + 1
		output = output .. string.format("%s %04x\n", m, vars[addr])
	end
end
for i, v in ipairs(labelinserts) do
	labelinserts[i] = string.format("%04x", labels[v] or 0)
end
o:write(output:format(unpack(labelinserts)))
o:close()
i:close()
