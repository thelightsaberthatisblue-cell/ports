local Reliable = require(script.Reliable)
local Unreliable = require(script.Unreliable)

----------------------------------------------------------------
-- REMOTES
----------------------------------------------------------------

local port = script:WaitForChild("Port")
local unreliablePort = script:WaitForChild("UnreliablePort")

Reliable.init(port)
Unreliable.init(unreliablePort)

----------------------------------------------------------------
-- PUBLIC API
----------------------------------------------------------------

local Ports = {}

Ports.Port = port
Ports.UnreliablePort = unreliablePort

-- Reliable listen
Ports.ListenOnServer            = Reliable.ListenOnServer
Ports.ListenForClient           = Reliable.ListenForClient
Ports.ListenOnClient            = Reliable.ListenOnClient
Ports.ListenForServer           = Reliable.ListenForServer

-- Reliable send (wrap to inject the remote)
function Ports.SendToServer(p, ...)       Reliable.SendToServer(port, p, ...) end
function Ports.SendToClient(player, p, ...) Reliable.SendToClient(port, player, p, ...) end
function Ports.Broadcast(p, ...)          Reliable.Broadcast(port, p, ...) end

-- Unreliable listen
Ports.UnreliablyListenOnClient  = Unreliable.UnreliablyListenOnClient
Ports.UnreliablyListenOnServer  = Unreliable.UnreliablyListenOnServer
Ports.UnreliablyListenForClient = Unreliable.UnreliablyListenForClient
Ports.UnreliablyListenForServer = Unreliable.UnreliablyListenForServer

-- Unreliable send (wrap to inject the remote)
function Ports.UnreliablySendToServer(p, ...)         Unreliable.UnreliablySendToServer(unreliablePort, p, ...) end
function Ports.UnreliablySendToClient(player, p, ...) Unreliable.UnreliablySendToClient(unreliablePort, player, p, ...) end
function Ports.UnreliablyBroadcast(p, ...)            Unreliable.UnreliablyBroadcast(unreliablePort, p, ...) end

-- Utils
function Ports.DisconnectAll(p)
	Reliable.DisconnectAll(p)
	Unreliable.DisconnectAll(p)
end

function Ports.ListAllListeners(p)
	local r = Reliable.ListAllListeners(p)
	local u = Unreliable.ListAllListeners(p)
	return {
		server           = r.server,
		client           = r.client,
		unreliableServer = u.unreliableServer,
		unreliableClient = u.unreliableClient,
	}
end

return Ports
