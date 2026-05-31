# Ports

Ports is a lightweight Roblox networking library that simplifies RemoteEvent usage by simulating a port-based messaging system. Instead of many RemoteEvents, Ports uses two channels (reliable and unreliable) and routes all messages using simple port numbers.

Normally in Roblox development you create multiple RemoteEvents, organize them in ReplicatedStorage, and repeat boilerplate. Ports replaces that with a single structured system acting like a signal-based router built on top of RemoteEvents.

Reliable communication is used for important gameplay events where delivery matters. Unreliable communication is faster but may drop messages and is meant for non-critical updates like effects or movement smoothing.

Ports works by sending a portnumber through the network. Listeners react only to matching ports, allowing many logical channels without creating extra RemoteEvents.

On the client you can listen using ListenOnClient and send using SendToServer. On the server you can receive using ListenOnServer, send to players using SendToClient, or broadcast using Broadcast.

Everything is designed to reduce ReplicatedStorage clutter while keeping communication structured and predictable. Module state exists only inside each server or client environment and does not replicate across servers.

Ports provides a clean signal-like API over RemoteEvents with a simple port routing system.

Example usage:

┌──────────────────────────────────────────────┐
│ Ports.ListenOnServer(5, function()           │
│     print("Server received port 5")          │
│ end)                                         │
│                                              │
│ Ports.SendToServer(5)                        │
└──────────────────────────────────────────────┘

Server → Client:

┌──────────────────────────────────────────────┐
│ Ports.SendToClient(player, 5)                │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│ Ports.ListenOnClient(5, function()           │
│     print("Client received port 5")          │
│ end)                                         │
└──────────────────────────────────────────────┘
