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

-- variables

---@type RemoteEvent
---Reliable RemoteEvent used for important gameplay communication
Ports.Port = script:WaitForChild("Port")

---@type RemoteEvent
---Unreliable RemoteEvent used for fast / non-critical communication
Ports.UnreliablePort = script:WaitForChild("UnreliablePort")

----------------------------------------------------------------
-- RELIABLE
----------------------------------------------------------------

-- client -> server

---@param portnumber any
---Sends a message from client to server using the reliable channel
function Ports.SendToServer(portnumber)
	Ports.Port:FireServer(portnumber)
end

---@param portnumber any
---@param callback function
---Waits for a specific port from the server once, then stops listening
function Ports.ListenForClient(portnumber, callback)
	local connection
	connection = Ports.Port.OnServerEvent:Connect(function(port)
		if port == portnumber then
			callback()
			connection:Disconnect()
		end
	end)
end

---@param portnumber any
---@param callback function
---Keeps listening on the server for a port (does not disconnect)
function Ports.ListenOnServer(portnumber, callback)
	return Ports.Port.OnServerEvent:Connect(function(port)
		if port == portnumber then
			callback()
		end
	end)
end

-- server -> client

---@param player Player
---@param portnumber any
---Sends a message from server to a specific client
function Ports.SendToClient(player, portnumber)
	Ports.Port:FireClient(player, portnumber)
end

---@param portnumber any
---Sends a message from server to all clients
function Ports.Broadcast(portnumber)
	Ports.Port:FireAllClients(portnumber)
end

---@param portnumber any
---@param callback function
---Waits for a specific message on the client once, then disconnects
function Ports.ListenForServer(portnumber, callback)
	local connection
	connection = Ports.Port.OnClientEvent:Connect(function(port)
		if port == portnumber then
			callback()
			connection:Disconnect()
		end
	end)
end

---@param portnumber any
---@param callback function
---Keeps listening on the client for server messages
function Ports.ListenOnClient(portnumber, callback)
	return Ports.Port.OnClientEvent:Connect(function(port)
		if port == portnumber then
			callback()
		end
	end)
end

----------------------------------------------------------------
-- UNRELIABLE
----------------------------------------------------------------

-- client -> server

---@param portnumber any
---Unreliable version of SendToServer (faster, not guaranteed)
function Ports.UnreliablySendToServer(portnumber)
	Ports.UnreliablePort:FireServer(portnumber)
end

---@param portnumber any
---@param callback function
---Unreliable one-time server listener
function Ports.UnreliablyListenForClient(portnumber, callback)
	local connection
	connection = Ports.UnreliablePort.OnServerEvent:Connect(function(port)
		if port == portnumber then
			callback()
			connection:Disconnect()
		end
	end)
end

---@param portnumber any
---@param callback function
---Unreliable persistent server listener
function Ports.UnreliablyListenOnServer(portnumber, callback)
	return Ports.UnreliablePort.OnServerEvent:Connect(function(port)
		if port == portnumber then
			callback()
		end
	end)
end

-- server -> client

---@param player Player
---@param portnumber any
---Unreliable send from server to one client
function Ports.UnreliablySendToClient(player, portnumber)
	Ports.UnreliablePort:FireClient(player, portnumber)
end

---@param portnumber any
---Unreliable broadcast to all clients
function Ports.UnreliablyBroadcast(portnumber)
	Ports.UnreliablePort:FireAllClients(portnumber)
end

---@param portnumber any
---@param callback function
---Unreliable one-time client listener
function Ports.UnreliablyListenForServer(portnumber, callback)
	local connection
	connection = Ports.UnreliablePort.OnClientEvent:Connect(function(port)
		if port == portnumber then
			callback()
			connection:Disconnect()
		end
	end)
end

---@param portnumber any
---@param callback function
---Unreliable persistent client listener
function Ports.UnreliablyListenOnClient(portnumber, callback)
	return Ports.UnreliablePort.OnClientEvent:Connect(function(port)
		if port == portnumber then
			callback()
		end
	end)
end

return Ports