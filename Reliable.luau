local Reliable = {}

----------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------

local RunService = game:GetService("RunService")
local IS_SERVER = RunService:IsServer()

----------------------------------------------------------------
-- TYPES
----------------------------------------------------------------

export type Signal = {
	Connect: (self: Signal, callback: (...any) -> ()) -> any
}

export type PortListener = {
	SignalReceived: Signal,
	Disconnected: Signal,
	Disconnect: () -> ()
}

----------------------------------------------------------------
-- REGISTRIES
----------------------------------------------------------------

local serverRegistry = {}
local clientRegistry = {}

----------------------------------------------------------------
-- UTIL
----------------------------------------------------------------

local function validPort(port)
	local t = typeof(port)
	return t == "string" or t == "number"
end

----------------------------------------------------------------
-- SIGNAL SYSTEM
----------------------------------------------------------------

local function createSignal()
	local listeners = {}

	return {
		Connect = function(_, callback)
			assert(typeof(callback) == "function", "[Ports] Signal callback must be a function")
			table.insert(listeners, callback)

			return {
				Disconnect = function()
					for i = #listeners, 1, -1 do
						if listeners[i] == callback then
							table.remove(listeners, i)
							break
						end
					end
				end
			}
		end,

		-- FIX 1: forward ... as task.spawn args, not via closure capture
		Fire = function(_, ...)
			for _, cb in ipairs(listeners) do
				task.spawn(function(...)
					local ok, err = pcall(cb, ...)
					if not ok then
						warn("[Ports] Signal error:", err)
					end
				end, ...)
			end
		end
	}
end

----------------------------------------------------------------
-- REGISTRY HELPERS
----------------------------------------------------------------

local function getOrCreateSignals(registry, port)
	if not registry[port] then
		registry[port] = {
			callbacks = {},
			signalReceived = createSignal(),
			disconnected = createSignal(),
		}
	end
	return registry[port]
end

local function addCallback(registry, port, once)
	assert(validPort(port), "[Ports] Invalid port")

	local bucket = getOrCreateSignals(registry, port)

	local entry = {
		once = once,
	}

	table.insert(bucket.callbacks, entry)

	local disconnected = false

	local function disconnect()
		if disconnected then return end
		disconnected = true

		local list = bucket.callbacks
		for i = #list, 1, -1 do
			if list[i] == entry then
				table.remove(list, i)
				break
			end
		end

		if #list == 0 then
			registry[port] = nil
		end

		bucket.disconnected:Fire()
	end

	-- Per-listener signals (FIX 1: SignalReceived is now the canonical data path)
	local signalReceived = createSignal()
	local disconnectedSignal = createSignal()
	entry.signalReceived = signalReceived
	entry.disconnectedSignal = disconnectedSignal

	return {
		SignalReceived = signalReceived,
		Disconnected = disconnectedSignal,
		Disconnect = disconnect,
	}
end

local function fireRegistry(registry, port, ...)
	local bucket = registry[port]
	if not bucket then return end

	local list = bucket.callbacks
	local args = table.pack(...)

	-- FIX 2: iterate up to snapshot length instead of cloning the table
	local snapLen = #list

	for i = 1, snapLen do
		local entry = list[i]
		if entry then
			task.spawn(function(...)
				entry.signalReceived:Fire(...)
			end, table.unpack(args, 1, args.n))
		end
	end

	-- FIX 3: single pass mark-and-sweep for once entries
	local i = snapLen
	while i >= 1 do
		if list[i] and list[i].once then
			list[i].disconnectedSignal:Fire()
			table.remove(list, i)
		end
		i -= 1
	end

	if #list == 0 then
		registry[port] = nil
	end
end

----------------------------------------------------------------
-- REMOTE HOOK SETUP
-- FIX 2 (Gemini): guard behind IsServer() to prevent cross-context crashes
----------------------------------------------------------------

function Reliable.init(remote)
	if IS_SERVER then
		remote.OnServerEvent:Connect(function(player, port, ...)
			if not validPort(port) then return end
			fireRegistry(serverRegistry, port, player, ...)
		end)
	else
		remote.OnClientEvent:Connect(function(port, ...)
			if not validPort(port) then return end
			fireRegistry(clientRegistry, port, ...)
		end)
	end
end

----------------------------------------------------------------
-- LISTEN API
----------------------------------------------------------------

-- Persistent server-side listener (client -> server)
function Reliable.ListenOnServer(port)
	return addCallback(serverRegistry, port, false)
end

-- One-shot server-side listener (client -> server)
function Reliable.ListenForClient(port)
	return addCallback(serverRegistry, port, true)
end

-- Persistent client-side listener (server -> client)
function Reliable.ListenOnClient(port)
	return addCallback(clientRegistry, port, false)
end

-- One-shot client-side listener (server -> client)
function Reliable.ListenForServer(port)
	return addCallback(clientRegistry, port, true)
end

----------------------------------------------------------------
-- SEND API
----------------------------------------------------------------

function Reliable.SendToServer(remote, port, ...)
	assert(not IS_SERVER, "[Ports] SendToServer must be called from the client")
	assert(validPort(port), "[Ports] Invalid port")
	remote:FireServer(port, ...)
end

function Reliable.SendToClient(remote, player, port, ...)
	assert(IS_SERVER, "[Ports] SendToClient must be called from the server")
	assert(validPort(port), "[Ports] Invalid port")
	remote:FireClient(player, port, ...)
end

function Reliable.Broadcast(remote, port, ...)
	assert(IS_SERVER, "[Ports] Broadcast must be called from the server")
	assert(validPort(port), "[Ports] Invalid port")
	remote:FireAllClients(port, ...)
end

----------------------------------------------------------------
-- UTILS
----------------------------------------------------------------

function Reliable.DisconnectAll(port)
	local registries = { serverRegistry, clientRegistry }

	if port then
		assert(validPort(port), "[Ports] Invalid port")
		for _, registry in ipairs(registries) do
			local bucket = registry[port]
			if bucket then
				bucket.disconnected:Fire()
				registry[port] = nil
			end
		end
	else
		for _, registry in ipairs(registries) do
			for currentPort, bucket in pairs(registry) do
				bucket.disconnected:Fire()
				registry[currentPort] = nil
			end
		end
	end
end

function Reliable.ListAllListeners(port)
	return {
		server = serverRegistry[port] and #serverRegistry[port].callbacks or 0,
		client = clientRegistry[port] and #clientRegistry[port].callbacks or 0,
	}
end

return Reliable
