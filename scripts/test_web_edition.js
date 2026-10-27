#!/usr/bin/env node

/**
 * Automated Verification Script for Castle Attack - Mobile Web Edition
 * Tests server startup, slot assignment, mirrored coordinate relay, and disconnects.
 */

const { WebSocket } = require('ws');
const http = require('http');

const PORT = 8080;

// Start server
require('../server.js');

setTimeout(() => {
    console.log('[Test] Connecting Client 1 (Player A)...');
    const c1 = new WebSocket(`ws://127.0.0.1:${PORT}`);
    let c2 = null;

    c1.on('open', () => console.log('  [C1] Connected'));
    c1.on('message', (raw) => {
        const msg = JSON.parse(raw.toString());
        console.log(`  [C1] Received: ${msg.type} ${msg.role || ''}`);

        if (msg.type === 'assignRole' && msg.role === 'playerA') {
            console.log('[Test] Connecting Client 2 (Player B)...');
            c2 = new WebSocket(`ws://127.0.0.1:${PORT}`);

            c2.on('open', () => console.log('  [C2] Connected'));
            c2.on('message', (raw2) => {
                const msg2 = JSON.parse(raw2.toString());
                console.log(`  [C2] Received: ${msg2.type} ${msg2.role || ''}`);

                if (msg2.type === 'matchReady') {
                    console.log('[Test] Testing mirrored projectile launch from C1 -> C2...');
                    c1.send(JSON.stringify({
                        type: 'launchProjectile',
                        card: 'stones',
                        origin: { x: 0.25, y: 0.78 },
                        velocity: { x: 0.1, y: -0.8 }
                    }));
                }

                if (msg2.type === 'launchProjectile') {
                    const oxMatch = Math.abs(msg2.origin.x - 0.75) < 0.001;
                    const oyMatch = Math.abs(msg2.origin.y - 0.22) < 0.001;
                    const vxMatch = Math.abs(msg2.velocity.x - (-0.1)) < 0.001;
                    const vyMatch = Math.abs(msg2.velocity.y - 0.8) < 0.001;

                    if (oxMatch && oyMatch && vxMatch && vyMatch) {
                        console.log('  ✅ PASS: Mirrored trajectory vector verified');
                        console.log('[Test] Testing disconnect handling...');
                        c2.close();
                    } else {
                        console.error('  ❌ FAIL: Coordinates not mirrored properly', msg2);
                        process.exit(1);
                    }
                }
            });
        }

        if (msg.type === 'peerDisconnected') {
            console.log('  ✅ PASS: Peer disconnect notification received');
            c1.close();
            setTimeout(() => {
                console.log('\n=======================================================');
                console.log('  ALL MOBILE WEB MULTIPLAYER TESTS PASSED 100%!');
                console.log('=======================================================\n');
                process.exit(0);
            }, 200);
        }
    });
}, 800);
