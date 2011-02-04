#!/usr/bin/env lua

local input = io.open(arg[1], "r")
local output = io.open(arg[2], "w")

local posses = {}

local bytecode = {
	--initialize the data pointer to 16
	0x03, 0x00, 0x10, --put 0010
	0x02, 0x00, 0x00, --set 0000
	0x06, 0x00, 0x00, --clear 0000
}

local scripts = {
	[">"] = function()
		return {
			--increase the data pointer
			0x01, 0x00, 0x00, --get 0000
			0x03, 0x00, 0x01, --put 0001
			0x0a, 0x00, 0x00, --add 0000
			0x02, 0x00, 0x00, --set 0000
			0x06, 0x00, 0x00, --clear 0000
		}
	end,
	["<"] = function()
		return {
			--decrease the data pointer
			0x01, 0x00, 0x00, --get 0000
			0x03, 0x00, 0x01, --put 0001
			0x0b, 0x00, 0x00, --sub 0000
			0x02, 0x00, 0x00, --set 0000
			0x06, 0x00, 0x00, --clear 0000
		}
	end,
	["+"] = function()
		return {
			--increase value at data pointer
			0x01, 0x00, 0x00, --get 0000
			0x01, 0x00, 0x00, --get 0000
			0x07, 0x00, 0x00, --getp 0000
			0x03, 0x00, 0x01, --put 0001
			0x0a, 0x00, 0x00, --add 0000
			0x18, 0x00, 0x00, --setp 0000
			0x06, 0x00, 0x00, --clear 0000
		}
	end,
	["-"] = function()
		return {
			--decrease value at data pointer
			0x01, 0x00, 0x00, --get 0000
			0x01, 0x00, 0x00, --get 0000
			0x07, 0x00, 0x00, --getp 0000
			0x03, 0x00, 0x01, --put 0001
			0x0b, 0x00, 0x00, --sub 0000
			0x18, 0x00, 0x00, --setp 0000
			0x06, 0x00, 0x00, --clear 0000
		}
	end,
	["."] = function()
		return {
			--output character at data pointer
			0x01, 0x00, 0x00, --get 0000
			0x07, 0x00, 0x00, --getp 0000
			0x03, 0x00, 0x00, --put 0000
			0x05, 0x00, 0x01, --call 0001
			0x06, 0x00, 0x00, --clear 0000
		}
	end,
	[","] = function()
		return {
			--one character input
			0x03, 0x00, 0x02, --put 0002
			0x03, 0x00, 0x01, --put 0001
			0x05, 0x00, 0x02, --call 0002
			0x06, 0x00, 0x00, --clear 0000
			0x01, 0x00, 0x00, --get 0000
			0x01, 0x00, 0x02, --get 0002
			0x18, 0x00, 0x00, --setp 0000
			0x06, 0x00, 0x00, --clear 0000
		}
	end,
	["["] = function()
		table.insert(posses, #bytecode/3)
		return {}
	end,
	["]"] = function()
		local pos = table.remove(posses)
		local pos_a, pos_b = math.floor(pos/256), pos%256
		return {
			--loop if non-zero
			0x01, 0x00, 0x00, --get 0000
			0x07, 0x00, 0x00, --getp 0000
			0x08, pos_a, pos_b, --goto (stored-pos)
		}
	end,
}

local program = input:read("*a")
input:close()

for c in program:gmatch(".") do
	local f = scripts[c]
	if f then
		local t = f()
		for i, v in ipairs(t) do
			table.insert(bytecode, v)
		end
	end
end
for i, v in ipairs(bytecode) do
	output:write(string.char(v))
end
output:close()
