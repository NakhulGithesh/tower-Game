#!/usr/bin/env node

/**
 * Castle Attack - WebSocket Relay Server
 * Relays real-time GamePackets between Player A (Blue) and Player B (Red) across ngrok / WAN.
 */

const http = require('http');
const { WebSocketServer, WebSocket } = require('ws');

const PORT = process.env.PORT || 8080;

let playerASocket = null;
let playerBSocket = null;

// HTTP Health & Status Server
const server = http.createServer((req, res) => {
    res.setHeader('Content-Type', 'application/json');
    res.writeHead(200);
    res.end(JSON.stringify({
        status: 'ok',
        service: 'CastleAttack-Relay',
        slots: {
            playerA: playerASocket !== null && playerASocket.readyState === WebSocket.OPEN,
            playerB: playerBSocket !== null && playerBSocket.readyState === WebSocket.OPEN
        }
    }));
});

// WebSocket Server attached to HTTP
const wss = new WebSocketServer({ server });

wss.on('connection', (ws, req) => {
    const remoteAddr = req.socket.remoteAddress;
    console.log(`[Relay] New incoming connection from ${remoteAddr}`);

    // Slot Assignment
    if (!playerASocket || playerASocket.readyState !== WebSocket.OPEN) {
        playerASocket = ws;
        ws.playerRole = 'playerA';
        console.log('[Relay] Assigned slot -> PLAYER A (Royal Blue)');
        ws.send(JSON.stringify({ type: 'assignRole', role: 'playerA' }));
    } else if (!playerBSocket || playerBSocket.readyState !== WebSocket.OPEN) {
        playerBSocket = ws;
        ws.playerRole = 'playerB';
        console.log('[Relay] Assigned slot -> PLAYER B (Crimson Red)');
        ws.send(JSON.stringify({ type: 'assignRole', role: 'playerB' }));

        // Both players are present: Notify both clients
        console.log('[Relay] Both players connected! Broadcasting matchReady.');
        const readyMessage = JSON.stringify({ type: 'matchReady' });
        if (playerASocket.readyState === WebSocket.OPEN) {
            playerASocket.send(readyMessage);
        }
        if (playerBSocket.readyState === WebSocket.OPEN) {
            playerBSocket.send(readyMessage);
        }
    } else {
        console.log('[Relay] Rejecting connection: Arena is full (2/2 slots active)');
        ws.send(JSON.stringify({ type: 'error', message: 'Arena is full (2/2 players connected)' }));
        ws.close(1008, 'Arena full');
        return;
    }

    // Message Relay Logic
    ws.on('message', (message, isBinary) => {
        const targetSocket = ws.playerRole === 'playerA' ? playerBSocket : playerASocket;
        if (targetSocket && targetSocket.readyState === WebSocket.OPEN) {
            targetSocket.send(message, { binary: isBinary });
        }
    });

    // Disconnect Handling
    ws.on('close', (code, reason) => {
        console.log(`[Relay] Socket closed for ${ws.playerRole} (Code: ${code}, Reason: ${reason})`);
        
        if (ws === playerASocket) {
            playerASocket = null;
            if (playerBSocket && playerBSocket.readyState === WebSocket.OPEN) {
                playerBSocket.send(JSON.stringify({ type: 'peerDisconnected', role: 'playerA' }));
            }
        } else if (ws === playerBSocket) {
            playerBSocket = null;
            if (playerASocket && playerASocket.readyState === WebSocket.OPEN) {
                playerASocket.send(JSON.stringify({ type: 'peerDisconnected', role: 'playerB' }));
            }
        }
    });

    ws.on('error', (err) => {
        console.error(`[Relay] Error on ${ws.playerRole}:`, err.message);
    });
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`=======================================================`);
    console.log(`  CASTLE ATTACK WEBSOCKET RELAY SERVER`);
    console.log(`  Listening on: ws://0.0.0.0:${PORT}`);
    console.log(`  Expose publicly via: ngrok http ${PORT}`);
    console.log(`=======================================================`);
});

// Graceful termination
const shutdown = () => {
    console.log('\n[Relay] Shutting down relay server...');
    wss.close(() => {
        server.close(() => {
            console.log('[Relay] Server terminated gracefully.');
            process.exit(0);
        });
    });
};

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
