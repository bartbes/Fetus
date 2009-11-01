#!/usr/bin/env lua

require("socket")

stack = {}
mem = {}
handles = {}
address = {"0.0.0.0", 0}
contexts = {}
contextpos = {}
curcontext = 0
pos = 0

function clear()
	while #stack ~= 0 do
			table.remove(stack)
	end
end

do
	local mt = {}
	function mt.__index() return 0 end
	setmetatable(stack, mt)
	setmetatable(mem, mt)
end

function readfd(fd, arg)
	if io.type(fd) then
		return fd:read(arg)
	else
		return fd:receive(arg)
	end
end

function writefd(fd, text)
	if io.type(fd) then
		return fd:write(text)
	else
		return fd:send(text)
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
		local text = io.read():sub(1, size-1)
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
		local id = #handles+1
		table.insert(handles, id, f)
		table.insert(stack, id-1)
	end,
	[0x0004] = function()		--fileclose
		local id = stack[1]+1
		clear()
		handles[id]:close()
		handles[id] = nil
	end,
	[0x0005] = function()		--read
		local id, pos, size = stack[1]+1, stack[2], stack[3]
		clear()
		local text = readfd(handles[id], size-1)
		for i = 0, size-1 do
			mem[pos+i] = text:sub(i+1, i+1) and string.byte(text:sub(i+1, i+1)) or 0
		end
		table.insert(stack, #text+1)
	end,
	[0x0006] = function()		--write
		local id = stack[1]+1
		table.remove(stack, 1)
		local text = ""
		for i, v in ipairs(stack) do
			if v == 0 then break end
			text = text .. string.char(v)
		end
		writefd(handles[id], text)
		clear()
	end,
	[0x0007] = function()		--tcp
		local ip = ""
		for i, v in ipairs(stack) do
			if v == 0 then break end
			ip = ip .. string.char(v)
		end
		local port = stack[#ip+2]
		clear()
		local sock = socket.tcp()
		local id = #handles+1
		table.insert(handles, id, sock)
		assert(sock:connect(ip, port))
		table.insert(stack, id-1)
	end,
	[0x0008] = function()		--udp
		clear()
		local sock = socket.udp()
		local id = #handles+1
		table.insert(handles, id, sock)
		table.insert(stack, id-1)
	end,
	[0x0009] = function()		--createip
		local addr, a, b, c, d = stack[1], stack[2], stack[3], stack[4], stack[5]
		clear()
		local s = string.format("%d.%d.%d.%d", a, b, c, d)
		for i = 0, #s-1 do
			mem[addr+i] = s:sub(i+1, i+1)
		end
		table.insert(stack, #s)
	end,
	[0x000a] = function()		--sendto
		local id = stack[1]+1
		table.remove(stack, 1)
		local text = ""
		while stack[1] ~= 0 do
			text = text .. string.char(table.remove(stack, 1))
		end
		table.remove(stack, 1)
		local ip = ""
		while stack[1] ~= 0 do
			ip = ip .. string.char(table.remove(stack, 1))
		end
		table.remove(stack, 1)
		local port = stack[1]
		clear()
		handles[id]:sendto(text, ip, port)
	end,
	[0x000b] = function()		--storeaddress
		local ip = ""
		while stack[1] ~= 0 do
			ip = ip .. string.char(table.remove(stack, 1))
		end
		table.remove(stack, 1)
		local port = stack[1]
		clear()
		address = {ip, port}
	end,
	[0x000c] = function()		--getaddress
		clear()
		local ip = address[1]
		local iplen = #ip
		local port = address[2]
		for i = 1, iplen do
			table.insert(stack, string.byte(ip:sub(1, 1)))
		end
		table.insert(stack, 0)
		table.insert(stack, port)
	end,
	[0x000d] = function()		--createcontext
		local s, e = (stack[#stack-1]-1)*3, (stack[#stack])*3
		clear()
		local data = contexts[1]:sub(s+1, e)
		local id = #contexts+1
		table.insert(contexts, id, data)
		table.insert(stack, id-1)
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
		stack[#stack] = mem[stack[#stack]]
	end,
	[0x08] = function(p)		--goto
		local b = stack[#stack] > 0
		clear()
		if b then
			pos = (p-1)*3
		end
	end,
	[0x09] = function()			--gotos
		local b, p = stack[#stack-1] > 0, stack[#stack]
		clear()
		if b then
			pos = (p-1)*3
		end
	end,
	[0x0a] = function()			--add
		local r = stack[#stack-1] + stack[#stack]
		stack[#stack] = nil
		stack[#stack] = r
	end,
	[0x0b] = function()			--sub
		local r = stack[#stack-1] - stack[#stack]
		stack[#stack] = nil
		stack[#stack] = r
	end,
	[0x0c] = function()			--mult
		local r = stack[#stack-1] * stack[#stack]
		stack[#stack] = nil
		stack[#stack] = r
	end,
	[0x0d] = function()			--div
		local r = math.floor(stack[#stack-1] / stack[#stack])
		stack[#stack] = nil
		stack[#stack] = r
	end,
	[0x0e] = function()			--pow
		local r = stack[#stack-1] ^ stack[#stack]
		stack[#stack] = nil
		stack[#stack] = r
	end,
	[0x0f] = function()			--root
		local r = math.floor(stack[#stack-1] ^ (1/stack[#stack]))
		stack[#stack] = nil
		stack[#stack] = r
	end,
	[0x10] = function()			--mod
		local r = stack[#stack-1] % stack[#stack]
		stack[#stack] = nil
		stack[#stack] = r
	end,
	[0x11] = function()			--eq
		local r = stack[#stack-1] == stack[#stack]
		stack[#stack] = nil
		stack[#stack] = r and 1 or 0
	end,
	[0x12] = function()			--lt
		local r = stack[#stack-1] < stack[#stack]
		stack[#stack] = nil
		stack[#stack] = r and 1 or 0
	end,
	[0x13] = function()			--gt
		local r = stack[#stack-1] > stack[#stack]
		stack[#stack] = nil
		stack[#stack] = r and 1 or 0
	end,
	[0x14] = function()			--not
		local r = stack[#stack] == 0
		stack[#stack] = r and 1 or 0
	end,
	[0x15] = function()			--pos
		clear()
		table.insert(stack, pos/3)
	end,
	[0x16] = function(address)			--ascii
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
		mem[stack[#stack-1]] = stack[#stack]
	end,
	[0x19] = function(c)				--ctxt
		local oldc = curcontext
		contextpos[curcontext] = pos
		curcontext = c+1
		pos = contextpos[curcontext] or 0
		clear()
		table.insert(stack, oldc-1)
	end,
	[0x1a] = function()					--ctxts
		local oldc = curcontext
		contextpos[curcontext] = pos
		curcontext = stack[#stack]+1
		pos = contextpos[curcontext] or 0
		clear()
		table.insert(stack, oldc-1)
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
local contents = i:read("*a")
i:close()
table.insert(contexts, contents)
local command, args
curcontext = 1
pos = 0
local line = contexts[curcontext]:sub(pos+1, pos+3)
while line ~= "" do
	command = string.byte(line:sub(1, 1))
	args = string.byte(line:sub(2, 2))
	args = args * 256 + string.byte(line:sub(3, 3))
	commands[command](args)
	pos = pos + 3
	line = contexts[curcontext]:sub(pos+1, pos+3)
end
print()
