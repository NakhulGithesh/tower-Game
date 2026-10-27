/**
 * Castle Attack - Mobile Web Edition Server
 * Serves static web assets and coordinates real-time mirrored multiplayer via WebSockets.
 */

const http = require('http');
const path = require('path');
const crypto = require('crypto');
const express = require('express');
const { WebSocketServer, WebSocket } = require('ws');

const app = express();
const PORT = process.env.PORT || 8080;

// Security: Disable x-powered-by header
app.disable('x-powered-by');

// Security: Set HTTP security headers on all responses
app.use((req, res, next) => {
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    res.setHeader(
        'Content-Security-Policy',
        "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self' ws: wss:; img-src 'self' data:;"
    );
    next();
});

// Serve public directory
app.use(express.static(path.join(__dirname, 'public')));

// Health & Status API
app.get('/api/status', (req, res) => {
    res.json({
        status: 'online',
        service: 'Castle Attack - Mobile Web Edition',
        slots: {
            playerA: playerASocket !== null && playerASocket.readyState === WebSocket.OPEN,
            playerB: playerBSocket !== null && playerBSocket.readyState === WebSocket.OPEN
        },
        gracePeriod: {
            playerA: playerADisconnectTimer !== null,
            playerB: playerBDisconnectTimer !== null
        },
        spectators: spectators.size
    });
});

const server = http.createServer(app);
const wss = new WebSocketServer({
    server,
    maxPayload: 4096 // 4KB max payload per message
});

const MAX_SPECTATORS = 10;
const VALID_CARDS = new Set(['arrows', 'shield', 'stones', 'repair', 'fireball', 'counter']);

let playerASocket = null;
let playerBSocket = null;
let playerAToken = null;
let playerBToken = null;
let playerADisconnectTimer = null;
let playerBDisconnectTimer = null;

const spectators = new Set();
let rematchRequests = new Set();

/**
 * Validate Origin header to prevent cross-site WebSocket hijacking (CSWSH)
 */
function isAllowedOrigin(origin) {
    if (!origin || origin === 'null') {
        return true; // Native apps, curl, local file
    }
    try {
        const url = new URL(origin);
        const host = url.hostname.toLowerCase();

        // Localhost & Loopback
        if (host === 'localhost' || host === '127.0.0.1' || host === '::1' || host === '[::1]') {
            return true;
        }

        // Ngrok tunnels
        if (
            host === 'ngrok-free.dev' || host.endsWith('.ngrok-free.dev') ||
            host === 'ngrok.io' || host.endsWith('.ngrok.io') ||
            host === 'ngrok.app' || host.endsWith('.ngrok.app')
        ) {
            return true;
        }

        // LAN IPs: 192.168.*.*, 10.*.*.*, 172.16-31.*.*
        if (/^192\.168\.\d{1,3}\.\d{1,3}$/.test(host)) return true;
        if (/^10\.\d{1,3}\.\d{1,3}$/.test(host)) return true;
        if (/^172\.(1[6-9]|2[0-9]|3[0-1])\.\d{1,3}\.\d{1,3}$/.test(host)) return true;

        return false;
    } catch {
        return false;
    }
}

function clamp(val, min, max) {
    if (typeof val !== 'number' || Number.isNaN(val) || !Number.isFinite(val)) {
        return null;
    }
    return Math.max(min, Math.min(max, val));
}

/**
 * Strict packet schema validation & sanitization
 */
function sanitizePayload(data) {
    if (!data || typeof data !== 'object') return null;

    switch (data.type) {
        case 'reconnect': {
            if (typeof data.token !== 'string' || !data.token.trim()) return null;
            return {
                type: 'reconnect',
                token: data.token.trim().slice(0, 128)
            };
        }

        case 'playAgain': {
            return { type: 'playAgain' };
        }

        case 'towerBuff': {
            if (data.towerIndex !== 0 && data.towerIndex !== 1) return null;
            if (typeof data.card !== 'string' || !VALID_CARDS.has(data.card)) return null;
            return {
                type: 'towerBuff',
                towerIndex: data.towerIndex,
                card: data.card
            };
        }

        case 'launchProjectile': {
            if (typeof data.card !== 'string' || !VALID_CARDS.has(data.card)) return null;
            if (!data.origin || typeof data.origin !== 'object') return null;
            if (!data.velocity || typeof data.velocity !== 'object') return null;

            const ox = clamp(data.origin.x, 0, 1);
            const oy = clamp(data.origin.y, 0, 1);
            const vx = clamp(data.velocity.x, -10, 10);
            const vy = clamp(data.velocity.y, -10, 10);

            if (ox === null || oy === null || vx === null || vy === null) return null;

            return {
                type: 'launchProjectile',
                card: data.card,
                origin: { x: ox, y: oy },
                velocity: { x: vx, y: vy }
            };
        }

        case 'syncHealth': {
            if (!Array.isArray(data.towerHealths) || data.towerHealths.length !== 2) return null;
            const h0 = clamp(data.towerHealths[0], 0, 500);
            const h1 = clamp(data.towerHealths[1], 0, 500);
            if (h0 === null || h1 === null) return null;

            return {
                type: 'syncHealth',
                towerHealths: [Math.round(h0), Math.round(h1)]
            };
        }

        default:
            return null;
    }
}

function mirrorPayload(payload) {
    const copy = JSON.parse(JSON.stringify(payload));
    if (copy.origin) {
        copy.origin.x = 1.0 - copy.origin.x;
        copy.origin.y = 1.0 - copy.origin.y;
    }
    if (copy.velocity) {
        copy.velocity.x = -copy.velocity.x;
        copy.velocity.y = -copy.velocity.y;
    }
    if (typeof copy.towerIndex === 'number') {
        copy.towerIndex = 1 - copy.towerIndex;
    }
    if (Array.isArray(copy.towerHealths)) {
        copy.towerHealths = [copy.towerHealths[1], copy.towerHealths[0]];
    }
    return copy;
}

function assignSlot(ws) {
    if (ws.readyState !== WebSocket.OPEN) return;
    if (ws.playerRole) return; // already assigned or reconnected

    // Slot A assignment
    if ((!playerASocket || playerASocket.readyState !== WebSocket.OPEN) && !playerADisconnectTimer) {
        playerASocket = ws;
        ws.playerRole = 'playerA';
        if (!playerAToken) playerAToken = crypto.randomUUID();
        ws.sessionToken = playerAToken;
        console.log('[WebArena] Assigned slot -> PLAYER A (Royal Blue)');
        ws.send(JSON.stringify({
            type: 'assignRole',
            role: 'playerA',
            team: 'blue',
            sessionToken: playerAToken
        }));
    } else if ((!playerBSocket || playerBSocket.readyState !== WebSocket.OPEN) && !playerBDisconnectTimer) {
        playerBSocket = ws;
        ws.playerRole = 'playerB';
        if (!playerBToken) playerBToken = crypto.randomUUID();
        ws.sessionToken = playerBToken;
        console.log('[WebArena] Assigned slot -> PLAYER B (Crimson Red)');
        ws.send(JSON.stringify({
            type: 'assignRole',
            role: 'playerB',
            team: 'red',
            sessionToken: playerBToken
        }));

        // Both players are connected -> Start match!
        console.log('[WebArena] Both players connected! Broadcasting matchReady.');
        rematchRequests.clear();
        const readyMsg = JSON.stringify({ type: 'matchReady' });
        if (playerASocket && playerASocket.readyState === WebSocket.OPEN) playerASocket.send(readyMsg);
        if (playerBSocket && playerBSocket.readyState === WebSocket.OPEN) playerBSocket.send(readyMsg);
    } else {
        if (spectators.size >= MAX_SPECTATORS) {
            console.log('[WebArena] Spectator limit reached. Rejecting client.');
            ws.send(JSON.stringify({ type: 'error', message: 'Spectator capacity reached' }));
            ws.close(1008, 'Spectator limit reached');
            return;
        }
        spectators.add(ws);
        ws.playerRole = 'spectator';
        console.log('[WebArena] Arena full -> Assigned SPECTATOR');
        ws.send(JSON.stringify({ type: 'assignRole', role: 'spectator', team: 'spectator' }));
    }
}

wss.on('connection', (ws, req) => {
    const remoteIp = req.socket.remoteAddress;
    const origin = req.headers.origin;

    // Origin Check
    if (!isAllowedOrigin(origin)) {
        console.warn(`[WebArena] Unauthorized origin: ${origin} from ${remoteIp}`);
        ws.close(1008, 'Unauthorized origin');
        return;
    }

    console.log(`[WebArena] Client connected from ${remoteIp} (Origin: ${origin || 'none'})`);

    // Per-socket rate limiter: max 30 msg/sec
    let messageCount = 0;
    let windowStart = Date.now();

    // If a player disconnected recently and is in grace period, give 150ms for reconnect message before allocating slot
    let slotTimer = null;
    if (playerADisconnectTimer || playerBDisconnectTimer) {
        slotTimer = setTimeout(() => {
            assignSlot(ws);
        }, 150);
    } else {
        assignSlot(ws);
    }

    // Packet Dispatching & Mirrored Relay
    ws.on('message', (messageText) => {
        const now = Date.now();
        if (now - windowStart >= 1000) {
            messageCount = 0;
            windowStart = now;
        }
        messageCount++;
        if (messageCount > 30) {
            console.warn(`[WebArena] Rate limit exceeded for ${ws.playerRole || 'unassigned'} from ${remoteIp}`);
            ws.close(1008, 'Rate limit exceeded');
            return;
        }

        let rawData;
        try {
            rawData = JSON.parse(messageText.toString());
        } catch {
            return;
        }

        const data = sanitizePayload(rawData);
        if (!data) {
            return;
        }

        // Handle Reconnect Token
        if (data.type === 'reconnect') {
            if (slotTimer) {
                clearTimeout(slotTimer);
                slotTimer = null;
            }

            if (playerAToken && data.token === playerAToken) {
                if (playerADisconnectTimer) {
                    clearTimeout(playerADisconnectTimer);
                    playerADisconnectTimer = null;
                    console.log('[WebArena] Player A reconnected within grace period.');
                }
                if (playerASocket && playerASocket !== ws && playerASocket.readyState === WebSocket.OPEN) {
                    playerASocket.close(1000, 'Replaced by new connection');
                }
                spectators.delete(ws);
                playerASocket = ws;
                ws.playerRole = 'playerA';
                ws.sessionToken = playerAToken;

                const oppConnected = playerBSocket !== null && playerBSocket.readyState === WebSocket.OPEN;
                ws.send(JSON.stringify({
                    type: 'reconnected',
                    role: 'playerA',
                    team: 'blue',
                    opponentConnected: oppConnected
                }));

                if (oppConnected) {
                    playerBSocket.send(JSON.stringify({ type: 'peerReconnected', role: 'playerA' }));
                }
                return;
            } else if (playerBToken && data.token === playerBToken) {
                if (playerBDisconnectTimer) {
                    clearTimeout(playerBDisconnectTimer);
                    playerBDisconnectTimer = null;
                    console.log('[WebArena] Player B reconnected within grace period.');
                }
                if (playerBSocket && playerBSocket !== ws && playerBSocket.readyState === WebSocket.OPEN) {
                    playerBSocket.close(1000, 'Replaced by new connection');
                }
                spectators.delete(ws);
                playerBSocket = ws;
                ws.playerRole = 'playerB';
                ws.sessionToken = playerBToken;

                const oppConnected = playerASocket !== null && playerASocket.readyState === WebSocket.OPEN;
                ws.send(JSON.stringify({
                    type: 'reconnected',
                    role: 'playerB',
                    team: 'red',
                    opponentConnected: oppConnected
                }));

                if (oppConnected) {
                    playerASocket.send(JSON.stringify({ type: 'peerReconnected', role: 'playerB' }));
                }
                return;
            } else {
                // Token did not match active slots -> regular assignment
                assignSlot(ws);
                return;
            }
        }

        // Gameplay actions require active player role
        if (ws.playerRole !== 'playerA' && ws.playerRole !== 'playerB') {
            return;
        }

        // Handle Rematch Coordination
        if (data.type === 'playAgain') {
            rematchRequests.add(ws.playerRole);
            if (rematchRequests.has('playerA') && rematchRequests.has('playerB')) {
                rematchRequests.clear();
                const resetMsg = JSON.stringify({ type: 'matchReady' });
                if (playerASocket && playerASocket.readyState === WebSocket.OPEN) playerASocket.send(resetMsg);
                if (playerBSocket && playerBSocket.readyState === WebSocket.OPEN) playerBSocket.send(resetMsg);
            } else {
                const waitMsg = JSON.stringify({ type: 'waitingForRematch', by: ws.playerRole });
                if (playerASocket && playerASocket.readyState === WebSocket.OPEN) playerASocket.send(waitMsg);
                if (playerBSocket && playerBSocket.readyState === WebSocket.OPEN) playerBSocket.send(waitMsg);
            }
            return;
        }

        // Normal packet relay with perspective mirroring
        if (ws === playerASocket) {
            if (playerBSocket && playerBSocket.readyState === WebSocket.OPEN) {
                const mirrored = mirrorPayload(data);
                mirrored.isOpponent = true;
                playerBSocket.send(JSON.stringify(mirrored));
            }
        } else if (ws === playerBSocket) {
            if (playerASocket && playerASocket.readyState === WebSocket.OPEN) {
                const mirrored = mirrorPayload(data);
                mirrored.isOpponent = true;
                playerASocket.send(JSON.stringify(mirrored));
            }
        }

        // Mirror to spectators (using Player A's perspective)
        for (const spec of spectators) {
            if (spec.readyState === WebSocket.OPEN) {
                const specPacket = ws === playerASocket ? data : mirrorPayload(data);
                spec.send(JSON.stringify(specPacket));
            }
        }
    });

    // Disconnect Handling with 10-second grace period
    ws.on('close', () => {
        if (slotTimer) {
            clearTimeout(slotTimer);
            slotTimer = null;
        }
        console.log(`[WebArena] Socket closed for ${ws.playerRole || 'unassigned'}`);

        if (ws === playerASocket) {
            playerASocket = null;
            rematchRequests.delete('playerA');
            console.log('[WebArena] Player A disconnected. 10-second reconnect grace period started.');
            if (playerADisconnectTimer) clearTimeout(playerADisconnectTimer);
            playerADisconnectTimer = setTimeout(() => {
                console.log('[WebArena] Player A grace period expired. Slot forfeited.');
                playerADisconnectTimer = null;
                playerAToken = null;
                if (playerBSocket && playerBSocket.readyState === WebSocket.OPEN) {
                    playerBSocket.send(JSON.stringify({ type: 'peerDisconnected', role: 'playerA' }));
                }
            }, 10000);
        } else if (ws === playerBSocket) {
            playerBSocket = null;
            rematchRequests.delete('playerB');
            console.log('[WebArena] Player B disconnected. 10-second reconnect grace period started.');
            if (playerBDisconnectTimer) clearTimeout(playerBDisconnectTimer);
            playerBDisconnectTimer = setTimeout(() => {
                console.log('[WebArena] Player B grace period expired. Slot forfeited.');
                playerBDisconnectTimer = null;
                playerBToken = null;
                if (playerASocket && playerASocket.readyState === WebSocket.OPEN) {
                    playerASocket.send(JSON.stringify({ type: 'peerDisconnected', role: 'playerB' }));
                }
            }, 10000);
        } else {
            spectators.delete(ws);
        }
    });

    ws.on('error', (err) => {
        console.error(`[WebArena] Error on ${ws.playerRole || 'client'}:`, err.message);
    });
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`=======================================================`);
    console.log(`  CASTLE ATTACK - MOBILE WEB EDITION`);
    console.log(`  Local URL:   http://localhost:${PORT}`);
    console.log(`  Network URL: http://0.0.0.0:${PORT}`);
    console.log(`=======================================================`);
});
