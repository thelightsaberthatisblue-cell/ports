# Ports

Ports is a lightweight Roblox networking library that simplifies RemoteEvent usage  
by simulating a port-based messaging system. Instead of creating many RemoteEvents,  
Ports uses two channels (reliable and unreliable) and routes all communication using  
simple port numbers.

In normal Roblox development, you typically create multiple RemoteEvents, organize  
them in ReplicatedStorage, and repeat similar boilerplate for each one. Ports replaces  
that with a single structured system that behaves like a signal-style event router  
built on top of RemoteEvents.

Reliable communication is intended for important gameplay events where delivery must  
be guaranteed, while unreliable communication is faster but may drop messages and is  
meant for non-critical updates such as visual effects or smooth movement syncing.

Ports works by sending a portnumber through the network, and listeners react only to  
the ports they are registered for. This allows many logical communication channels  
without creating additional RemoteEvents.

On the client, Ports can listen for server messages or send data back to the server.  
On the server, it can receive client messages, send data to specific players, or  
broadcast to all clients using the same routing system.

The entire system is designed to reduce ReplicatedStorage clutter while keeping  
communication structured, predictable, and easy to manage. Module state exists only  
within the same server or client environment and does not replicate across servers.

Overall, Ports provides a clean, signal-like API over Roblox RemoteEvents using a  
simple and scalable port-based routing approach.

---

# Function Reference

Ports.SendToServer  
Sends a message from the client to the server using a specific port number.  
Used when the client needs to request or trigger something on the server.

Ports.ListenForClient  
Listens on the server for a specific port from a client.  
Automatically disconnects after the first matching message is received.  
Useful for one-time requests or actions.

Ports.ListenOnServer  
Continuously listens on the server for a specific port from clients.  
Does not disconnect automatically and keeps reacting to matching messages.  
Useful for persistent server-side event handling.

Ports.SendToClient  
Sends a message from the server to a specific player using a port number.  
Used for targeted communication such as UI updates or player-specific events.

Ports.Broadcast  
Sends a message from the server to all connected clients using a port number.  
Useful for global events like round starts, effects, or announcements.

Ports.ListenForServer  
Listens on the client for a specific port from the server.  
Automatically disconnects after the first matching message is received.  
Used for one-time server responses.

Ports.ListenOnClient  
Continuously listens on the client for server messages using a port number.  
Does not disconnect automatically and handles repeated events over time.  
Used for ongoing client-side updates.

Ports.UnreliablySendToServer  
Same as SendToServer but uses the unreliable channel.  
Faster but not guaranteed to arrive. Used for non-critical data.

Ports.UnreliablyListenForClient  
One-time server listener using the unreliable channel.  
Disconnects after first matching message.

Ports.UnreliablyListenOnServer  
Persistent server listener using the unreliable channel.  
Handles repeated non-critical client messages.

Ports.UnreliablySendToClient  
Sends a message from server to a client using the unreliable channel.  
Used for fast updates where occasional loss is acceptable.

Ports.UnreliablyBroadcast  
Broadcasts a message to all clients using the unreliable channel.  
Used for frequent or non-critical global updates.

Ports.UnreliablyListenForServer  
One-time client listener for unreliable server messages.  
Disconnects after first match.

Ports.UnreliablyListenOnClient  
Persistent client listener for unreliable server messages.  
Used for continuous non-critical updates from the server.
