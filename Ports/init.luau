local Ports = {}

Ports.Port = script:WaitForChild("Port")
Ports.UnreliablePort = script:WaitForChild("UnreliablePort")

function Ports.SendInPort(portnumber)
	Ports.Port:FireAllClients(portnumber)
end

function Ports.ListenOnPort(portnumber, callback)
	local connection
	connection = Ports.Port.OnClientEvent:Connect(function(port)
		if port == portnumber then
			callback()
			connection:Disconnect()
		end
	end)
end

function Ports.UnreliablySendInPort(portnumber)
    Ports.UnreliablePort:FireAllClients(portnumber)
end

function Ports.UnreliablyListenOnPort(portnumber, callback)
    local connection
    connection = Ports.UnreliablePort.OnClientEvent:Connect(function(port)
        if port == portnumber then
            callback()
            connection:Disconnect()
        end
    end)
end

return Ports