local Unreliable = {}

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

export type UnreliablePortListener = {
	SignalReceived: Signal,
	Disconnected: Signal,
	Timeout: Signal,
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

local function getOrCreateBucket(registry, port)
	if not registry[port] then
		registry[port] = {
			callbacks = {},
			disconnected = createSignal(),
		}
	end
	return registry[port]
end

local function addCallback(registry, port, once, listenTime)
	assert(validPort(port), "[Ports] Invalid port")

	if listenTime ~= nil then
		assert(typeof(listenTime) == "number", "[Ports] listenTime must be a number")
	end

	local bucket = getOrCreateBucket(registry, port)

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

		entry.disconnectedSignal:Fire()
	end

	-- FIX 1: per-listener signals, SignalReceived is the canonical data path
	-- FIX 4: Timeout is per-listener, not shared on bucket
	local signalReceived = createSignal()
	local disconnectedSignal = createSignal()
	entry.signalReceived = signalReceived
	entry.disconnectedSignal = disconnectedSignal

	if listenTime then
		local timeoutSignal = createSignal()
		entry.timeoutSignal = timeoutSignal

		task.delay(listenTime, function()
			if disconnected then return end
			-- FIX 5 (Gemini): pass port so consumer knows which channel timed out
			timeoutSignal:Fire(port)
			disconnect()
		end)

		return {
			SignalReceived = signalReceived,
			Disconnected = disconnectedSignal,
			Timeout = timeoutSignal,
			Disconnect = disconnect,
		}
	end

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

	-- FIX 2: snapshot length instead of cloning the table
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

function Unreliable.init(remote)
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

-- Persistent client-side listener (server -> client, unreliable)
function Unreliable.UnreliablyListenOnClient(port, listenTime)
	return addCallback(clientRegistry, port, false, listenTime)
end

-- Persistent server-side listener (client -> server, unreliable)
function Unreliable.UnreliablyListenOnServer(port, listenTime)
	return addCallback(serverRegistry, port, false, listenTime)
end

-- One-shot server-side listener (client -> server, unreliable)
function Unreliable.UnreliablyListenForClient(port, listenTime)
	return addCallback(serverRegistry, port, true, listenTime)
end

-- One-shot client-side listener (server -> client, unreliable)
function Unreliable.UnreliablyListenForServer(port, listenTime)
	return addCallback(clientRegistry, port, true, listenTime)
end

----------------------------------------------------------------
-- SEND API
----------------------------------------------------------------

function Unreliable.UnreliablySendToServer(remote, port, ...)
	assert(not IS_SERVER, "[Ports] UnreliablySendToServer must be called from the client")
	assert(validPort(port), "[Ports] Invalid port")
	remote:FireServer(port, ...)
end

function Unreliable.UnreliablySendToClient(remote, player, port, ...)
	assert(IS_SERVER, "[Ports] UnreliablySendToClient must be called from the server")
	assert(validPort(port), "[Ports] Invalid port")
	remote:FireClient(player, port, ...)
end

function Unreliable.UnreliablyBroadcast(remote, port, ...)
	assert(IS_SERVER, "[Ports] UnreliablyBroadcast must be called from the server")
	assert(validPort(port), "[Ports] Invalid port")
	remote:FireAllClients(port, ...)
end

----------------------------------------------------------------
-- UTILS
----------------------------------------------------------------

function Unreliable.DisconnectAll(port)
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

function Unreliable.ListAllListeners(port)
	return {
		unreliableServer = serverRegistry[port] and #serverRegistry[port].callbacks or 0,
		unreliableClient = clientRegistry[port] and #clientRegistry[port].callbacks or 0,
	}
end

return Unreliable
