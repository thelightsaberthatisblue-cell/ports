local Ports = {}

----------------------------------------------------------------
--[[
Ports is a lightweight RemoteEvent routing system.

Instead of creating many RemoteEvents, you use:
- one reliable channel (Port)
- one unreliable channel (UnreliablePort)
- a "port number" to decide what message is for what system
]]
----------------------------------------------------------------

-- types

export type PortConnection = {
	Disconnect: () -> ()
}

-- variables

---@type RemoteEvent
Ports.Port = script:WaitForChild("Port")

---@type UnreliableRemoteEvent
Ports.UnreliablePort = script:WaitForChild("UnreliablePort")

-- internal registries
-- structure: registry[portnumber] = { {callback = fn, once = bool} }

local serverRegistry = {}
local clientRegistry = {}
local unreliableServerRegistry = {}
local unreliableClientRegistry = {}

-- exploit protection

local function validPort(port)
	local t = typeof(port)
	return t == "string" or t == "number"
end

-- internal helpers

local function addCallback(registry, portnumber, callback, once, listenTime)
	assert(validPort(portnumber), "[Ports] Invalid port type: port must be a string or number, got " .. typeof(portnumber))
	assert(typeof(callback) == "function", "[Ports] Invalid callback: expected a function, got " .. typeof(callback))

	if not registry[portnumber] then
		registry[portnumber] = {}
	end

	local entry = { callback = callback, once = once }
	table.insert(registry[portnumber], entry)

	local isDisconnected = false

	local proxy: PortConnection = {
		Disconnect = function()
			if isDisconnected then return end
			isDisconnected = true
			local list = registry[portnumber]
			if not list then return end
			for i = #list, 1, -1 do
				if list[i] == entry then
					table.remove(list, i)
					break
				end
			end
			if #list == 0 then
				registry[portnumber] = nil
			end
		end
	}

	if listenTime then
		task.delay(listenTime, function()
			if isDisconnected then return end
			proxy.Disconnect()
		end)
	end

	return proxy
end

local function fireRegistry(registry, portnumber, ...)
	local list = registry[portnumber]
	if not list then return end

	local args = table.pack(...)

	-- 1. fire all callbacks in registration order
	for i = 1, #list do
		local entry = list[i]
		if entry then
			task.spawn(function()
				local ok, err = pcall(entry.callback, table.unpack(args, 1, args.n))
				if not ok then
					warn("[Ports]", err)
				end
			end)
		end
	end

	-- 2. clean up once entries safely afterward
	for i = #list, 1, -1 do
		local entry = list[i]
		if entry and entry.once then
			table.remove(list, i)
		end
	end

	-- 3. garbage collect the table key if no listeners remain
	if #list == 0 then
		registry[portnumber] = nil
	end
end

-- single connections at init

Ports.Port.OnServerEvent:Connect(function(player, port, ...)
	if not validPort(port) then return end
	fireRegistry(serverRegistry, port, player, ...)
end)

Ports.Port.OnClientEvent:Connect(function(port, ...)
	if not validPort(port) then return end
	fireRegistry(clientRegistry, port, ...)
end)

Ports.UnreliablePort.OnServerEvent:Connect(function(player, port, ...)
	if not validPort(port) then return end
	fireRegistry(unreliableServerRegistry, port, player, ...)
end)

Ports.UnreliablePort.OnClientEvent:Connect(function(port, ...)
	if not validPort(port) then return end
	fireRegistry(unreliableClientRegistry, port, ...)
end)

----------------------------------------------------------------
-- RELIABLE
----------------------------------------------------------------

-- client -> server

---@param portnumber any
---Sends a message from client to server using the reliable channel
function Ports.SendToServer(portnumber, ...)
	Ports.Port:FireServer(portnumber, ...)
end

---@param portnumber any
---Waits for a specific port from the client once, then stops listening — use :Connect(callback)
function Ports.ListenForClient(portnumber)
	return {
		Connect = function(_, callback): PortConnection
			return addCallback(serverRegistry, portnumber, callback, true, nil)
		end
	}
end

---@param portnumber any
---Keeps listening on the server for a port — use :Connect(callback)
function Ports.ListenOnServer(portnumber)
	return {
		Connect = function(_, callback): PortConnection
			return addCallback(serverRegistry, portnumber, callback, false, nil)
		end
	}
end

-- server -> client

---@param player Player
---@param portnumber any
---Sends a message from server to a specific client
function Ports.SendToClient(player, portnumber, ...)
	Ports.Port:FireClient(player, portnumber, ...)
end

---@param portnumber any
---Sends a message from server to all clients
function Ports.Broadcast(portnumber, ...)
	Ports.Port:FireAllClients(portnumber, ...)
end

---@param portnumber any
---Waits for a specific message on the client once, then disconnects — use :Connect(callback)
function Ports.ListenForServer(portnumber)
	return {
		Connect = function(_, callback): PortConnection
			return addCallback(clientRegistry, portnumber, callback, true, nil)
		end
	}
end

---@param portnumber any
---Keeps listening on the client for server messages — use :Connect(callback)
function Ports.ListenOnClient(portnumber)
	return {
		Connect = function(_, callback): PortConnection
			return addCallback(clientRegistry, portnumber, callback, false, nil)
		end
	}
end

----------------------------------------------------------------
-- UNRELIABLE
----------------------------------------------------------------

-- client -> server

---@param portnumber any
---Unreliable version of SendToServer (faster, not guaranteed)
function Ports.UnreliablySendToServer(portnumber, ...)
	Ports.UnreliablePort:FireServer(portnumber, ...)
end

---@param portnumber any
---@param listenTime number
---Unreliable one-time server listener, auto-disconnects after listenTime seconds or on first match — use :Connect(callback)
function Ports.UnreliablyListenForClient(portnumber, listenTime)
	return {
		Connect = function(_, callback): PortConnection
			return addCallback(unreliableServerRegistry, portnumber, callback, true, listenTime)
		end
	}
end

---@param portnumber any
---@param listenTime number
---Unreliable persistent server listener, auto-disconnects after listenTime seconds — use :Connect(callback)
function Ports.UnreliablyListenOnServer(portnumber, listenTime)
	return {
		Connect = function(_, callback): PortConnection
			return addCallback(unreliableServerRegistry, portnumber, callback, false, listenTime)
		end
	}
end

-- server -> client

---@param player Player
---@param portnumber any
---Unreliable send from server to one client
function Ports.UnreliablySendToClient(player, portnumber, ...)
	Ports.UnreliablePort:FireClient(player, portnumber, ...)
end

---@param portnumber any
---Unreliable broadcast to all clients
function Ports.UnreliablyBroadcast(portnumber, ...)
	Ports.UnreliablePort:FireAllClients(portnumber, ...)
end

---@param portnumber any
---@param listenTime number
---Unreliable one-time client listener, auto-disconnects after listenTime seconds or on first match — use :Connect(callback)
function Ports.UnreliablyListenForServer(portnumber, listenTime)
	return {
		Connect = function(_, callback): PortConnection
			return addCallback(unreliableClientRegistry, portnumber, callback, true, listenTime)
		end
	}
end

---@param portnumber any
---@param listenTime number
---Unreliable persistent client listener, auto-disconnects after listenTime seconds — use :Connect(callback)
function Ports.UnreliablyListenOnClient(portnumber, listenTime)
	return {
		Connect = function(_, callback): PortConnection
			return addCallback(unreliableClientRegistry, portnumber, callback, false, listenTime)
		end
	}
end

return Ports
