#!/usr/bin/env lua

require("socket")

stack = {}
mem = {}
handles = {}

function clear()
	while #stack ~= 0 do
			table.remove(stack)
	end
end

funcs = {
	[0x0001] = function()		--output
		for i, v in ipairs(stack) do
			if v == 0 then break end
			io.write(string.char(v))
		end
		clear()
	end,
	[0x0002] = function()		--input
		local pos, size = stack[1], stack[2]
		clear()
		local text = io.read(size-1)
		for i = 0, size-1 do
			mem[pos+i] = text:sub(i+1, i+1) and string.byte(text:sub(i+1, i+1)) or 0
		end
		table.insert(stack, #text+1)
	end,
	[0x0003] = function()		--fileopen
		local fname = ""
		local mode
		for i, v in ipairs(stack) do
			if v == 0 then break end
			fname = fname .. string.char(v)
		end
		mode = stack[#fname+2]
		clear()
		if mode == 1 then
			mode = "r"
		elseif mode == 2 then
			mode = "w"
		elseif mode == 3 then
			mode = "a"
		end
		local f = io.open(fname, mode)
		table.insert(handles, f)
		table.insert(stack, #handles)
	end,
	[0x0004] = function()		--fileclose
		local id = stack[1]
		clear()
		handles[id]:close()
		handles[id] = nil
	end,
	[0x0005] = function()		--read
		local id, pos, size = stack[1], stack[2], stack[3]
		clear()
		local text = handles[id]:read(size-1)
		for i = 0, size-1 do
			mem[pos+i] = text:sub(i+1, i+1) and string.byte(text:sub(i+1, i+1)) or 0
		end
		table.insert(stack, #text+1)
	end,
	[0x0006] = function()		--write
		local id = stack[1]
		table.remove(stack, 1)
		local text = ""
		for i, v in ipairs(stack) do
			if v == 0 then break end
			text = text .. string.char(v)
		end
		handles[id]:write(text)
		clear()
	end,
	[0xFFFF] = function()		--debug
		print(stack[#stack])
	end,
}

commands = {
	[0x01] = function(address)	--get
		table.insert(stack, mem[address] or 0)
	end,
	[0x02] = function(address)	--set
		local stack = stack
		mem[address] = stack[#stack]
	end,
	[0x03] = function(value)	--put
		table.insert(stack, value)
	end,
	[0x04] = function()			--pop
		table.remove(stack)
	end,
	[0x05] = function(func)		--call
		funcs[func]()
	end,
	[0x06] = function()			--clear
		clear()
	end,
	[0x07] = function()			--getp
		local stack = stack
		stack[#stack] = mem[stack[#stack]]
	end,
	[0x08] = function(p)		--goto
		local stack = stack
		local b = stack[#stack] > 0
		clear()
		if b then
			pos = p*3
		end
	end,
	[0x09] = function()			--gotos
		local stack = stack
		local b, p = stack[#stack-1] > 0, stack[#stack]
		clear()
		if b then
			pos = p*3
		end
	end,
	[0x0a] = function()			--add
		local stack = stack
		local r = stack[#stack-1] + stack[#stack]
		stack[#stack] = nil
		stack[#stack] = r
	end,
	[0x0b] = function()			--sub
		local stack = stack
		local r = stack[#stack-1] - stack[#stack]
		stack[#stack] = nil
		stack[#stack] = r
	end,
	[0x0c] = function()			--mult
		local stack = stack
		local r = stack[#stack-1] * stack[#stack]
		stack[#stack] = nil
		stack[#stack] = r
	end,
	[0x0d] = function()			--div
		local stack = stack
		local r = math.floor(stack[#stack-1] / stack[#stack])
		stack[#stack] = nil
		stack[#stack] = r
	end,
	[0x0e] = function()			--pow
		local stack = stack
		local r = stack[#stack-1] ^ stack[#stack]
		stack[#stack] = nil
		stack[#stack] = r
	end,
	[0x0f] = function()			--root
		local stack = stack
		local r = math.floor(stack[#stack-1] ^ (1/stack[#stack]))
		stack[#stack] = nil
		stack[#stack] = r
	end,
	[0x10] = function()			--mod
		local stack = stack
		local r = stack[#stack-1] % stack[#stack]
		stack[#stack] = nil
		stack[#stack] = r
	end,
	[0x11] = function()			--eq
		local stack = stack
		local r = stack[#stack-1] == stack[#stack]
		stack[#stack] = nil
		stack[#stack] = r and 1 or 0
	end,
	[0x12] = function()			--lt
		local stack = stack
		local r = stack[#stack-1] < stack[#stack]
		stack[#stack] = nil
		stack[#stack] = r and 1 or 0
	end,
	[0x13] = function()			--gt
		local stack = stack
		local r = stack[#stack-1] > stack[#stack]
		stack[#stack] = nil
		stack[#stack] = r and 1 or 0
	end,
	[0x14] = function()			--not
		local stack = stack
		local r = stack[#stack] == 0
		stack[#stack] = r and 1 or 0
	end,
	[0x15] = function()			--pos
		clear()
		table.insert(stack, i:seek()/3)
	end,
	[0x16] = function(address)			--ascii
		local stack = stack
		local s = string.format("%d", stack[#stack])
		for i = 0, #s-1 do
			mem[address+i] = s:sub(i+1, i+1) and string.byte(s:sub(i+1, i+1)) or 0
		end
		table.insert(stack, #s)
	end,
	[0x17] = function(address)			--num
		local c = 0
		local s = ""
		while true do
			if not mem[address+c] or mem[address+c] == 0 then break end
			s = s .. string.char(mem[address+c])
			c = c + 1
		end
		table.insert(stack, tonumber(s))
	end,
	[0x18] = function()					--setp
		local stack = stack
		mem[stack[#stack-1]] = stack[#stack]
	end,
}

if not arg then
	print("Must be called from the command line")
	return 1
end
if #arg < 1 then
	print("Usage: " .. arg[0] .. " <infile>")
	return 1
end
i = arg[1] == "-" and io.stdin or io.open(arg[1])
if not i then
	print("Could not open file " .. arg[1])
	return 1
end
if #arg > 1 then
	for i = 2, #arg do
		table.insert(stack, arg[i])
	end
end
local file = i:read("*a")
i:close()
local line = file:sub(1, 3)
pos = 3
local command, args
while line ~= "" do
	command = string.byte(line:sub(1, 1))
	args = string.byte(line:sub(2, 2))
	args = args * 256 + string.byte(line:sub(3, 3))
	commands[command](args)
	line = file:sub(pos+1, pos+3)
	pos = pos + 3
end
print()
