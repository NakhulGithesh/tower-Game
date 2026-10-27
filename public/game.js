/**
 * Castle Attack - Mobile Web Edition (AAA Visual Overhaul)
 * High-Polish 2.5D Procedural Canvas Engine • Clash Royale / Kingdom Rush Aesthetic
 */

(function () {
    'use strict';

    // --- LOGICAL DIMENSIONS ---
    const LOGICAL_W = 400;
    const LOGICAL_H = 800;

    // --- GAME CONSTANTS ---
    const MAX_ELIXIR = 10;
    const ELIXIR_RECHARGE_RATE = 1.0 / 1.5; // +1 elixir every 1.5s
    const INITIAL_ELIXIR = 4.0;
    const MAX_TOWER_HP = 500;

    // 6 Cards in strict elixir cost progression
    const CARDS = [
        { id: 'arrows', name: 'Arrows', cost: 2, role: 'attack', dmg: 40, split: 3, color: '#38bdf8' },
        { id: 'shield', name: 'Shield', cost: 3, role: 'defense', duration: 5.0, color: '#06b6d4' },
        { id: 'stones', name: 'Stones', cost: 4, role: 'attack', dmg: 180, shake: true, color: '#f59e0b' },
        { id: 'repair', name: 'Repair', cost: 4, role: 'defense', heal: 150, duration: 5.0, color: '#22c55e' },
        { id: 'fireball', name: 'Fireball', cost: 5, role: 'attack', dmg: 100, burn: 50, color: '#f97316' },
        { id: 'counter', name: 'Counter', cost: 5, role: 'hybrid', dmg: 120, duration: 5.0, color: '#eab308' }
    ];

    // --- DOM REFERENCES ---
    const container = document.getElementById('app-container');
    const canvas = document.getElementById('game-canvas');
    const ctx = canvas.getContext('2d');

    const hudRoleText = document.getElementById('hud-role-text');
    const hudTeamDot = document.getElementById('hud-team-dot');
    const btnSoloToggle = document.getElementById('btn-solo-toggle');
    const btnMuteToggle = document.getElementById('btn-mute-toggle');
    const notificationBanner = document.getElementById('notification-banner');

    const modalWaiting = document.getElementById('modal-waiting');
    const waitingSubtitle = document.getElementById('waiting-subtitle');
    const btnSwitchSolo = document.getElementById('btn-switch-solo');

    const modalGameOver = document.getElementById('modal-gameover');
    const gameoverTitle = document.getElementById('gameover-title');
    const gameoverSubtitle = document.getElementById('gameover-subtitle');
    const btnPlayAgain = document.getElementById('btn-play-again');
    const btnRematchSolo = document.getElementById('btn-rematch-solo');

    // --- GAME STATE ---
    let state = 'LOBBY'; // 'WAITING', 'BATTLE', 'GAMEOVER'
    let isSoloAI = false;
    let myRole = 'playerA'; // 'playerA' (Blue) or 'playerB' (Red)
    let myTeam = 'blue';

    let currentElixir = INITIAL_ELIXIR;
    let lastTime = 0;
    let globalTime = 0;
    let screenShake = 0;

    // Towers: 2 Friendly (bottom), 2 Opponent (top)
    let myTowers = [];
    let oppTowers = [];

    // Interactive Entities
    let projectiles = [];
    let particles = [];
    let floatingTexts = [];
    let shockwaves = [];
    let debrisBlocks = [];

    // Drag & Aiming State
    let draggingCard = null;
    let dragPos = { x: 0, y: 0 };
    let armedTower = null; // Tower entered slingshot aiming
    let aimDragPos = null;

    // WebSocket Networking
    let ws = null;
    let isConnected = false;

    // --- INITIALIZATION ---
    function init() {
        resizeCanvas();
        window.addEventListener('resize', resizeCanvas);

        resetBattleState();
        setupInputHandlers();
        setupUIButtons();
        connectWebSocket();

        requestAnimationFrame(gameLoop);
    }

    function resetBattleState() {
        currentElixir = INITIAL_ELIXIR;
        projectiles = [];
        particles = [];
        floatingTexts = [];
        shockwaves = [];
        debrisBlocks = [];
        draggingCard = null;
        armedTower = null;
        aimDragPos = null;

        // Friendly Towers at Bottom (y = 625)
        myTowers = [
            createTower(0, 100, 625, 'Left Fortress', true),
            createTower(1, 300, 625, 'Right Fortress', true)
        ];

        // Opponent Towers at Top (y = 175)
        oppTowers = [
            createTower(0, 100, 175, 'Left Citadel', false),
            createTower(1, 300, 175, 'Right Citadel', false)
        ];
    }

    function createTower(index, x, y, name, isFriendly) {
        return {
            index,
            x,
            y,
            name,
            isFriendly,
            hp: MAX_TOWER_HP,
            maxHp: MAX_TOWER_HP,
            radius: 34,
            isDestroyed: false,
            // Ability locks & buffs
            shieldUntil: 0,
            repairUntil: 0,
            counterUntil: 0,
            cardLockUntil: 0,
            activeCard: null,
            wobble: 0,
            damageFractureSeed: Math.random() * 100
        };
    }

    // --- WEBSOCKET TRANSPORT ---
    function connectWebSocket() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${window.location.host}`;

        try {
            ws = new WebSocket(wsUrl);
        } catch (e) {
            console.warn('[WebArena] WebSocket creation failed. Fallback to Solo AI.', e);
            startSoloAI();
            return;
        }

        ws.onopen = () => {
            isConnected = true;
            console.log('[WebArena] Connected to relay server');
            const savedToken = sessionStorage.getItem('castle_session_token');
            if (savedToken) {
                ws.send(JSON.stringify({ type: 'reconnect', token: savedToken }));
            }
        };

        ws.onmessage = (event) => {
            try {
                const msg = JSON.parse(event.data);
                handleServerMessage(msg);
            } catch (e) {
                console.error('[WebArena] Packet decode error:', e);
            }
        };

        ws.onclose = () => {
            isConnected = false;
            if (state === 'BATTLE' && !isSoloAI) {
                showNotification('Connection lost. Reconnecting...');
            }
            if (!isSoloAI) {
                setTimeout(() => {
                    if (!isConnected && !isSoloAI) {
                        connectWebSocket();
                    }
                }, 1500);
            }
        };

        ws.onerror = (err) => {
            console.warn('[WebArena] WebSocket error:', err);
        };
    }

    function handleServerMessage(msg) {
        switch (msg.type) {
            case 'assignRole':
                myRole = msg.role;
                myTeam = msg.team || (msg.role === 'playerA' ? 'blue' : 'red');
                if (msg.sessionToken) {
                    sessionStorage.setItem('castle_session_token', msg.sessionToken);
                }
                updateHUDStatus();

                if (myRole === 'playerA') {
                    state = 'WAITING';
                    showWaitingModal(true);
                }
                break;

            case 'reconnected':
                myRole = msg.role;
                myTeam = msg.team || (msg.role === 'playerA' ? 'blue' : 'red');
                updateHUDStatus();
                if (msg.opponentConnected) {
                    showWaitingModal(false);
                    hideGameOverModal();
                    state = 'BATTLE';
                } else if (myRole === 'playerA') {
                    state = 'WAITING';
                    showWaitingModal(true);
                }
                showNotification('Reconnected to match');
                break;

            case 'peerReconnected':
                showNotification('Opponent reconnected');
                sendPacket({
                    type: 'syncHealth',
                    towerHealths: [myTowers[0].hp, myTowers[1].hp]
                });
                break;

            case 'matchReady':
                showWaitingModal(false);
                hideGameOverModal();
                resetBattleState();
                state = 'BATTLE';
                showNotification('⚔️ BATTLE COMMENCED!');
                window.sound.playVictory();
                break;

            case 'launchProjectile':
                spawnOpponentProjectile(msg);
                break;

            case 'towerBuff':
                if (oppTowers[msg.towerIndex]) {
                    applyBuffToTower(oppTowers[msg.towerIndex], msg.card, false);
                }
                break;

            case 'syncHealth':
                if (Array.isArray(msg.towerHealths)) {
                    oppTowers[0].hp = msg.towerHealths[0];
                    oppTowers[1].hp = msg.towerHealths[1];
                    checkTowerDestruction(oppTowers[0]);
                    checkTowerDestruction(oppTowers[1]);
                }
                break;

            case 'peerDisconnected':
                if (state === 'BATTLE') {
                    showNotification('⚠️ Opponent left match');
                } else if (state === 'WAITING') {
                    showNotification('Waiting for new challenger...');
                }
                break;
        }
    }

    function sendPacket(data) {
        if (isSoloAI) return;
        if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(data));
        }
    }

    // --- RESIZE & DPR SCALING ---
    let scale = 1;
    let canvasOffset = { x: 0, y: 0 };

    function resizeCanvas() {
        const rect = container.getBoundingClientRect();
        const dpr = window.devicePixelRatio || 1;

        canvas.width = rect.width * dpr;
        canvas.height = rect.height * dpr;

        const scaleX = rect.width / LOGICAL_W;
        const scaleY = rect.height / LOGICAL_H;
        scale = Math.min(scaleX, scaleY);

        canvasOffset.x = (rect.width - LOGICAL_W * scale) / 2;
        canvasOffset.y = (rect.height - LOGICAL_H * scale) / 2;

        ctx.setTransform(dpr * scale, 0, 0, dpr * scale, dpr * canvasOffset.x, dpr * canvasOffset.y);
    }

    function getLogicalCoords(e) {
        const rect = canvas.getBoundingClientRect();
        const clientX = e.touches ? e.touches[0].clientX : e.clientX;
        const clientY = e.touches ? e.touches[0].clientY : e.clientY;

        const rawX = clientX - rect.left - canvasOffset.x;
        const rawY = clientY - rect.top - canvasOffset.y;

        return {
            x: rawX / scale,
            y: rawY / scale
        };
    }

    // --- GAMEPLAY ACTIONS ---
    function tryApplyCard(card, tower) {
        const now = performance.now() / 1000;

        // Check if tower is busy or destroyed
        if (tower.isDestroyed || (tower.cardLockUntil > now)) {
            tower.wobble = 14;
            window.sound.vibrate([60]);
            showNotification('Tower Busy!');
            return false;
        }

        // Elixir check
        if (currentElixir < card.cost) {
            showNotification('Need more Elixir!');
            return false;
        }

        // Deduct elixir
        currentElixir -= card.cost;
        window.sound.playCardPlay();

        if (card.role === 'defense') {
            // Instant Buff
            applyBuffToTower(tower, card.id, true);
            sendPacket({ type: 'towerBuff', towerIndex: tower.index, card: card.id });
            return true;
        } else {
            // Armed for Slingshot launch
            armedTower = tower;
            armedTower.activeCard = card;
            aimDragPos = { x: tower.x, y: tower.y };
            window.sound.vibrate([20]);
            return true;
        }
    }

    function applyBuffToTower(tower, cardId, isLocal) {
        const now = performance.now() / 1000;
        tower.cardLockUntil = now + 5.0;
        tower.activeCard = CARDS.find(c => c.id === cardId);

        if (cardId === 'shield') {
            tower.shieldUntil = now + 5.0;
            window.sound.playShield();
            createShieldBurst(tower.x, tower.y);
            showFloatingText(tower.x, tower.y - 50, 'SHIELDED', '#38bdf8');
        } else if (cardId === 'repair') {
            tower.repairUntil = now + 5.0;
            window.sound.playRepair();
            showFloatingText(tower.x, tower.y - 50, '+150 REPAIR', '#22c55e');
        } else if (cardId === 'counter') {
            tower.counterUntil = now + 5.0;
            window.sound.playShield();
            showFloatingText(tower.x, tower.y - 50, 'MIRROR WARD', '#eab308');
        }
    }

    function launchArmedProjectile(tower, card, pullVector) {
        const now = performance.now() / 1000;
        tower.cardLockUntil = now + 0.5;
        tower.activeCard = null;

        // Impulses calibrated so pull back reaches upper towers effortlessly
        const impulse = 16.5 * (card.id === 'stones' ? 1.35 : (card.id === 'counter' ? 2.0 : 1.15));
        const vx = -pullVector.x * impulse;
        const vy = -pullVector.y * impulse;

        const origin = { x: tower.x, y: tower.y - 36 };
        const velocity = { x: vx, y: vy };

        createProjectile(card, origin, velocity, true);
        window.sound.playBowRelease();
        window.sound.playWhoosh();
        window.sound.vibrate([25, 45]);

        sendPacket({
            type: 'launchProjectile',
            card: card.id,
            origin: { x: origin.x / LOGICAL_W, y: origin.y / LOGICAL_H },
            velocity: { x: velocity.x / LOGICAL_W, y: velocity.y / LOGICAL_H }
        });
    }

    function spawnOpponentProjectile(msg) {
        const card = CARDS.find(c => c.id === msg.card) || CARDS[0];
        const origin = {
            x: msg.origin.x * LOGICAL_W,
            y: msg.origin.y * LOGICAL_H
        };
        const velocity = {
            x: msg.velocity.x * LOGICAL_W,
            y: msg.velocity.y * LOGICAL_H
        };

        createProjectile(card, origin, velocity, false);
        window.sound.playWhoosh();
    }

    function createProjectile(card, origin, velocity, isFriendly) {
        projectiles.push({
            id: Math.random().toString(36).substr(2, 9),
            card,
            isFriendly,
            x: origin.x,
            y: origin.y,
            vx: velocity.x,
            vy: velocity.y,
            gravity: card.id === 'stones' ? 780 : (card.id === 'counter' ? 120 : 650),
            age: 0,
            hasSplit: false,
            trailTimer: 0,
            rotation: 0
        });
    }

    // --- FRAME UPDATE LOOP ---
    function gameLoop(timestamp) {
        if (!lastTime) lastTime = timestamp;
        const dt = Math.min((timestamp - lastTime) / 1000, 0.1);
        lastTime = timestamp;
        globalTime += dt;

        update(dt);
        render();

        requestAnimationFrame(gameLoop);
    }

    function update(dt) {
        const now = performance.now() / 1000;

        // 1. Elixir recharge
        if (state === 'BATTLE') {
            currentElixir = Math.min(MAX_ELIXIR, currentElixir + dt * ELIXIR_RECHARGE_RATE);
            if (isSoloAI) updateSoloAI(dt);
        }

        // 2. Tower periodic heals & wobble dampening
        [...myTowers, ...oppTowers].forEach(tower => {
            if (tower.wobble > 0) tower.wobble = Math.max(0, tower.wobble - dt * 25);

            if (!tower.isDestroyed && tower.repairUntil > now) {
                tower.hp = Math.min(tower.maxHp, tower.hp + dt * 30);
                if (Math.random() < 0.35) {
                    createSparkle(tower.x + (Math.random() - 0.5) * 44, tower.y + (Math.random() - 0.5) * 44, '#22c55e');
                }
            }

            // Severe damage smoke puffs
            if (!tower.isDestroyed && tower.hp <= tower.maxHp * 0.4 && Math.random() < 0.15) {
                createSmokePuff(tower.x + (Math.random() - 0.5) * 28, tower.y - 10 + (Math.random() - 0.5) * 20);
            }
        });

        // 3. Screen shake decay
        if (screenShake > 0) {
            screenShake = Math.max(0, screenShake - dt * 28);
        }

        // 4. Update shockwaves
        for (let i = shockwaves.length - 1; i >= 0; i--) {
            const sw = shockwaves[i];
            sw.r += dt * sw.speed;
            sw.alpha -= dt * 2.2;
            if (sw.alpha <= 0) shockwaves.splice(i, 1);
        }

        // 5. Update debris rubble blocks
        for (let i = debrisBlocks.length - 1; i >= 0; i--) {
            const d = debrisBlocks[i];
            d.x += d.vx * dt;
            d.y += d.vy * dt;
            d.vy += 850 * dt;
            d.rot += d.vRot * dt;
            d.life -= dt;
            if (d.life <= 0) debrisBlocks.splice(i, 1);
        }

        // 6. Update projectiles
        for (let i = projectiles.length - 1; i >= 0; i--) {
            const p = projectiles[i];
            p.age += dt;
            p.x += p.vx * dt;
            p.y += p.vy * dt;
            p.vy += p.gravity * dt;
            p.rotation += dt * 8;

            // Projectile Trails
            p.trailTimer += dt;
            if (p.trailTimer > 0.025) {
                p.trailTimer = 0;
                createTrailParticle(p);
            }

            // Arrow split at 0.35s
            if (p.card.id === 'arrows' && !p.hasSplit && p.age >= 0.32) {
                p.hasSplit = true;
                window.sound.playWhoosh(0.18);
                createArrowBurst(p.x, p.y);

                const spreadAngle = 0.22;
                const vMag = Math.hypot(p.vx, p.vy);
                const currentAngle = Math.atan2(p.vy, p.vx);

                [-spreadAngle, spreadAngle].forEach(offset => {
                    const ang = currentAngle + offset;
                    projectiles.push({
                        id: Math.random().toString(),
                        card: p.card,
                        isFriendly: p.isFriendly,
                        x: p.x,
                        y: p.y,
                        vx: Math.cos(ang) * vMag,
                        vy: Math.sin(ang) * vMag,
                        gravity: p.gravity,
                        age: p.age,
                        hasSplit: true,
                        trailTimer: 0,
                        rotation: 0
                    });
                });
            }

            // Collision check with target towers
            const targetTowers = p.isFriendly ? oppTowers : myTowers;
            let hit = false;

            for (const tower of targetTowers) {
                if (tower.isDestroyed) continue;
                const dist = Math.hypot(p.x - tower.x, p.y - tower.y);

                // Shield dome intercept
                if (tower.shieldUntil > now && dist <= tower.radius + 18) {
                    hit = true;
                    window.sound.playImpact(0.5);
                    createShieldBurst(p.x, p.y);
                    showFloatingText(tower.x, tower.y - 35, 'BLOCKED!', '#38bdf8');
                    break;
                }

                // Direct Tower Hit
                if (dist <= tower.radius + 14) {
                    hit = true;
                    applyProjectileImpact(p, tower);
                    break;
                }
            }

            // Boundary despawn
            if (hit || p.y < -50 || p.y > LOGICAL_H + 50 || p.x < -50 || p.x > LOGICAL_W + 50) {
                projectiles.splice(i, 1);
            }
        }

        // 7. Update particles
        for (let i = particles.length - 1; i >= 0; i--) {
            const pt = particles[i];
            pt.age += dt;
            pt.x += pt.vx * dt;
            pt.y += pt.vy * dt;
            pt.alpha = Math.max(0, 1 - pt.age / pt.life);
            if (pt.age >= pt.life) {
                particles.splice(i, 1);
            }
        }

        // 8. Update floating text popups
        for (let i = floatingTexts.length - 1; i >= 0; i--) {
            const ft = floatingTexts[i];
            ft.age += dt;
            ft.y -= dt * 26;
            ft.scale = Math.min(1.25, 1.0 + Math.sin(ft.age * 8) * 0.25);
            ft.alpha = Math.max(0, 1 - ft.age / ft.life);
            if (ft.age >= ft.life) {
                floatingTexts.splice(i, 1);
            }
        }

        // 9. Check Victory Condition
        if (state === 'BATTLE') {
            const myAlive = myTowers.some(t => !t.isDestroyed);
            const oppAlive = oppTowers.some(t => !t.isDestroyed);

            if (!myAlive || !oppAlive) {
                state = 'GAMEOVER';
                const won = myAlive;
                showGameOverModal(won);
            }
        }
    }

    function applyProjectileImpact(p, tower) {
        const now = performance.now() / 1000;
        let dmg = p.card.dmg;

        // Counterattack Mirror Ward reflection
        if (tower.counterUntil > now) {
            tower.counterUntil = 0;
            window.sound.playExplosion();
            createLightningBurst(tower.x, tower.y);
            showFloatingText(tower.x, tower.y - 45, 'COUNTERED!', '#eab308');

            const counterTargets = p.isFriendly ? myTowers : oppTowers;
            const attackerTower = counterTargets[0].isDestroyed ? counterTargets[1] : counterTargets[0];
            if (attackerTower && !attackerTower.isDestroyed) {
                attackerTower.hp = Math.max(0, attackerTower.hp - dmg);
                showFloatingText(attackerTower.x, attackerTower.y - 40, `-${dmg}`, '#ef4444');
                checkTowerDestruction(attackerTower);
            }
            return;
        }

        // Screen shake & hit wobble
        tower.wobble = p.card.id === 'stones' ? 14 : 8;
        if (p.card.shake) {
            screenShake = 12;
            shockwaves.push({ x: tower.x, y: tower.y, r: 8, maxR: 45, speed: 220, alpha: 1.0 });
        }

        // Apply Damage
        tower.hp = Math.max(0, tower.hp - dmg);
        window.sound.playImpact(p.card.id === 'stones' ? 1.0 : 0.65);
        showFloatingText(tower.x, tower.y - 40, `-${dmg}`, '#ef4444');

        // Particle FX
        if (p.card.id === 'stones') {
            createStoneDebris(tower.x, tower.y);
        } else if (p.card.id === 'fireball') {
            createFireExplosion(tower.x, tower.y);
        } else {
            createArrowBurst(tower.x, tower.y);
        }

        checkTowerDestruction(tower);

        if (!p.isFriendly) {
            sendPacket({
                type: 'syncHealth',
                towerHealths: [myTowers[0].hp, myTowers[1].hp]
            });
        }
    }

    function checkTowerDestruction(tower) {
        if (tower.hp <= 0 && !tower.isDestroyed) {
            tower.isDestroyed = true;
            tower.hp = 0;
            screenShake = 18;
            window.sound.playExplosion();
            shockwaves.push({ x: tower.x, y: tower.y, r: 12, maxR: 75, speed: 300, alpha: 1.0 });
            createTowerCollapseFX(tower.x, tower.y);
            showFloatingText(tower.x, tower.y - 55, 'TOWER SHATTERED!', '#f97316');
        }
    }

    // --- RENDER PIPELINE ---
    function render() {
        ctx.save();

        // 3D Screen shake impulse + micro rotational tilt
        if (screenShake > 0) {
            const rx = (Math.random() - 0.5) * screenShake;
            const ry = (Math.random() - 0.5) * screenShake;
            const rTilt = (Math.random() - 0.5) * screenShake * 0.003;
            ctx.translate(rx, ry);
            ctx.rotate(rTilt);
        }

        // 1. Rich 2.5D Living Arena Terrain
        renderArenaTerrain();

        // 2. Shockwaves underneath flying items
        renderShockwaves();

        // 3. Falling/bouncing debris chunks
        renderDebrisBlocks();

        // 4. Procedural 2.5D Castle Towers
        oppTowers.forEach(t => renderProceduralTower(t, false));
        myTowers.forEach(t => renderProceduralTower(t, true));

        // 5. Slingshot Aim & Trajectory
        renderSlingshotAim();

        // 6. 3D Shaded Projectiles
        renderProjectiles();

        // 7. Particles & Floating Combat Text
        renderParticles();
        renderFloatingTexts();

        // 8. Clash Royale Glass Elixir Bar & Procedural Vector Card Deck
        renderBottomDock();

        ctx.restore();
    }

    // ==========================================
    // 1. LIVING ARENA ENVIRONMENT (CLASH ROYALE)
    // ==========================================
    function renderArenaTerrain() {
        const time = globalTime;

        // Base obsidian stone border
        ctx.fillStyle = '#0f172a';
        ctx.fillRect(0, 0, LOGICAL_W, LOGICAL_H);

        // --- OPPONENT TERRITORY (TOP: y = 46 to 365) ---
        // Scorched stone courtyard with diamond flagstone paving
        const oppGrad = ctx.createLinearGradient(0, 46, 0, 365);
        oppGrad.addColorStop(0, '#1c1917');
        oppGrad.addColorStop(1, '#292524');
        ctx.fillStyle = oppGrad;
        ctx.fillRect(16, 46, LOGICAL_W - 32, 320);

        // Diamond paver tile lattice
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.06)';
        ctx.lineWidth = 1;
        const tileSize = 28;
        ctx.save();
        ctx.beginPath();
        for (let x = -300; x < LOGICAL_W + 300; x += tileSize) {
            ctx.moveTo(x, 46);
            ctx.lineTo(x + 320, 366);
            ctx.moveTo(x + 320, 46);
            ctx.lineTo(x, 366);
        }
        ctx.stroke();
        ctx.restore();

        // Opponent Top Castle Wall Crenellations
        ctx.fillStyle = '#1c1917';
        ctx.fillRect(16, 46, LOGICAL_W - 32, 14);
        ctx.fillStyle = '#44403c';
        for (let bx = 22; bx < LOGICAL_W - 22; bx += 30) {
            ctx.fillRect(bx, 44, 18, 16);
            ctx.fillStyle = '#78716c';
            ctx.fillRect(bx + 1, 44, 16, 3); // lit top rim
            ctx.fillStyle = '#44403c';
        }

        // --- PLAYER TERRITORY (BOTTOM: y = 435 to 670) ---
        // Lush multi-toned emerald lawn
        const playGrad = ctx.createLinearGradient(0, 435, 0, 670);
        playGrad.addColorStop(0, '#15803d');
        playGrad.addColorStop(1, '#166534');
        ctx.fillStyle = playGrad;
        ctx.fillRect(16, 435, LOGICAL_W - 32, 236);

        // Mowing checkerboard lawn pattern
        ctx.fillStyle = 'rgba(34, 197, 94, 0.18)';
        for (let r = 0; r < 4; r++) {
            for (let c = 0; c < 5; c++) {
                if ((r + c) % 2 === 0) {
                    ctx.fillRect(18 + c * 72, 438 + r * 58, 72, 58);
                }
            }
        }

        // Scattered wildflower / grass tuft details
        ctx.fillStyle = '#fef08a';
        [
            { x: 45, y: 480 }, { x: 180, y: 520 }, { x: 350, y: 490 },
            { x: 80, y: 640 }, { x: 220, y: 650 }, { x: 340, y: 630 }
        ].forEach(f => {
            ctx.beginPath();
            ctx.arc(f.x, f.y, 2, 0, Math.PI * 2);
            ctx.fill();
        });

        // Cobblestone lanes leading to bridges
        renderCobblestonePath(100, 625, 100, 435);
        renderCobblestonePath(300, 625, 300, 435);
        renderCobblestonePath(100, 175, 100, 365);
        renderCobblestonePath(300, 175, 300, 365);

        // --- LIVING CENTRAL RIVER (y = 368 to 432) ---
        const riverGrad = ctx.createLinearGradient(0, 368, 0, 432);
        riverGrad.addColorStop(0, '#0c4a6e');
        riverGrad.addColorStop(0.35, '#0284c7');
        riverGrad.addColorStop(0.7, '#0369a1');
        riverGrad.addColorStop(1, '#082f49');
        ctx.fillStyle = riverGrad;
        ctx.fillRect(16, 368, LOGICAL_W - 32, 66);

        // Riverbanks Foam / Shore Water lines
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.55)';
        ctx.lineWidth = 1.8;
        ctx.beginPath();
        for (let x = 16; x <= LOGICAL_W - 16; x += 8) {
            const foamY1 = 371 + Math.sin(time * 3 + x * 0.1) * 1.5;
            const foamY2 = 431 + Math.sin(time * 3.5 + x * 0.1) * 1.5;
            if (x === 16) {
                ctx.moveTo(x, foamY1);
            } else {
                ctx.lineTo(x, foamY1);
            }
        }
        ctx.stroke();

        // Flowing Water Caustics / Sine Ripples
        ctx.strokeStyle = 'rgba(224, 242, 254, 0.3)';
        ctx.lineWidth = 2;
        for (let i = 0; i < 5; i++) {
            const flowX = ((i * 85 + time * 32) % (LOGICAL_W - 40)) + 20;
            const cy = 385 + (i % 3) * 14;
            ctx.beginPath();
            ctx.arc(flowX, cy, 26, Math.PI * 0.1, Math.PI * 0.7);
            ctx.stroke();
        }

        // --- 3D PERSPECTIVE COBBLESTONE ARCH BRIDGES (Left x=100, Right x=300) ---
        [100, 300].forEach(bx => {
            // Water cast shadow underneath bridge
            ctx.fillStyle = 'rgba(0, 0, 0, 0.65)';
            ctx.fillRect(bx - 26, 370, 52, 64);

            // Barrel arch opening
            ctx.fillStyle = '#0f172a';
            ctx.beginPath();
            ctx.ellipse(bx, 400, 18, 12, 0, 0, Math.PI);
            ctx.fill();

            // Cobblestone Bridge Deck
            const bridgeGrad = ctx.createLinearGradient(bx - 24, 0, bx + 24, 0);
            bridgeGrad.addColorStop(0, '#57534e');
            bridgeGrad.addColorStop(0.5, '#78716c');
            bridgeGrad.addColorStop(1, '#57534e');
            ctx.fillStyle = bridgeGrad;
            ctx.fillRect(bx - 24, 366, 48, 70);

            // Shaded cobblestones
            ctx.strokeStyle = '#292524';
            ctx.lineWidth = 1.2;
            for (let by = 370; by < 432; by += 10) {
                ctx.beginPath();
                ctx.moveTo(bx - 22, by);
                ctx.lineTo(bx + 22, by);
                ctx.stroke();
            }

            // Heavy Timber Handrails with Brass Finials
            ctx.fillStyle = '#78350f';
            ctx.fillRect(bx - 27, 365, 5, 72);
            ctx.fillRect(bx + 22, 365, 5, 72);

            // Brass rail posts
            ctx.fillStyle = '#d97706';
            [368, 388, 412, 432].forEach(py => {
                ctx.fillRect(bx - 28, py, 7, 3);
                ctx.fillRect(bx + 21, py, 7, 3);
            });
        });

        // --- ARENA PERIMETER BORDER WITH CORNER TORCHES ---
        ctx.strokeStyle = '#475569';
        ctx.lineWidth = 5;
        ctx.strokeRect(16, 46, LOGICAL_W - 32, 625);

        // 4 Corner Braziers with Flickering Fire Particles
        const brazierPoints = [
            { x: 30, y: 62 }, { x: LOGICAL_W - 30, y: 62 },
            { x: 30, y: 654 }, { x: LOGICAL_W - 30, y: 654 }
        ];

        brazierPoints.forEach(pt => {
            // Radial light halo
            const fireFlicker = Math.sin(time * 12 + pt.x) * 3;
            const haloGrad = ctx.createRadialGradient(pt.x, pt.y, 2, pt.x, pt.y, 28 + fireFlicker);
            haloGrad.addColorStop(0, 'rgba(251, 146, 60, 0.45)');
            haloGrad.addColorStop(1, 'rgba(251, 146, 60, 0)');
            ctx.fillStyle = haloGrad;
            ctx.beginPath();
            ctx.arc(pt.x, pt.y, 28 + fireFlicker, 0, Math.PI * 2);
            ctx.fill();

            // Iron bowl
            ctx.fillStyle = '#1e293b';
            ctx.beginPath();
            ctx.arc(pt.x, pt.y + 4, 8, 0, Math.PI * 2);
            ctx.fill();

            // Flickering Flame Core
            ctx.fillStyle = Math.random() < 0.5 ? '#f97316' : '#facc15';
            ctx.beginPath();
            ctx.arc(pt.x, pt.y + fireFlicker * 0.2, 5, 0, Math.PI * 2);
            ctx.fill();
        });
    }

    function renderCobblestonePath(x1, y1, x2, y2) {
        ctx.save();
        ctx.fillStyle = '#44403c';
        const steps = 14;
        for (let i = 0; i <= steps; i++) {
            const t = i / steps;
            const px = x1 + (x2 - x1) * t;
            const py = y1 + (y2 - y1) * t;
            ctx.fillRect(px - 14, py - 4, 28, 7);
        }
        ctx.restore();
    }

    // ==========================================
    // 2. PROCEDURAL 2.5D CASTLE TOWER
    // ==========================================
    function renderProceduralTower(tower, isFriendly) {
        ctx.save();
        const time = globalTime;

        // Elastic Hit Wobble
        const wobbleX = tower.wobble ? Math.sin(time * 30) * tower.wobble : 0;
        ctx.translate(tower.x + wobbleX, tower.y);

        // --- DESTROYED TOWER RUBBLE STATE ---
        if (tower.isDestroyed) {
            // Charred scorch mark on ground
            ctx.fillStyle = 'rgba(12, 10, 9, 0.75)';
            ctx.beginPath();
            ctx.ellipse(0, 10, 36, 22, 0, 0, Math.PI * 2);
            ctx.fill();

            // Shattered jagged stone stump
            ctx.fillStyle = '#292524';
            ctx.strokeStyle = '#1c1917';
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.moveTo(-24, 12);
            ctx.lineTo(-20, -4);
            ctx.lineTo(-12, 2);
            ctx.lineTo(-4, -10);
            ctx.lineTo(6, -2);
            ctx.lineTo(16, -8);
            ctx.lineTo(24, 12);
            ctx.closePath();
            ctx.fill();
            ctx.stroke();

            // Rubble pile chunks
            ctx.fillStyle = '#57534e';
            ctx.fillRect(-14, 2, 10, 8);
            ctx.fillRect(4, 6, 12, 7);
            ctx.fillRect(-6, 8, 14, 6);

            // Rising glowing ash embers
            if (Math.random() < 0.25) {
                createSparkle(tower.x + (Math.random() - 0.5) * 24, tower.y + 4, '#f97316');
            }

            ctx.restore();
            return;
        }

        // --- 1. DIRECTIONAL GROUND SHADOW ---
        ctx.fillStyle = 'rgba(0, 0, 0, 0.42)';
        ctx.beginPath();
        ctx.ellipse(6, 20, 38, 16, Math.PI * 0.08, 0, Math.PI * 2);
        ctx.fill();

        // Target Proximity Halo Ring (when dragging card onto this tower)
        if (draggingCard && isFriendly && Math.hypot(dragPos.x - tower.x, dragPos.y - tower.y) <= 65) {
            ctx.save();
            ctx.strokeStyle = '#facc15';
            ctx.lineWidth = 3.5;
            ctx.shadowColor = '#f59e0b';
            ctx.shadowBlur = 12;
            ctx.beginPath();
            ctx.arc(0, 4, tower.radius + 16, 0, Math.PI * 2);
            ctx.stroke();

            // Rotating reticle glyphs
            ctx.rotate(time * 3);
            for (let i = 0; i < 4; i++) {
                ctx.rotate(Math.PI / 2);
                ctx.fillStyle = '#fef08a';
                ctx.fillRect(tower.radius + 12, -2, 6, 4);
            }
            ctx.restore();
        }

        // --- 2. CYLINDRICAL STONE SHAFT (3D DEPTH LIGHTING) ---
        const shaftW = 54;
        const shaftH = 46;
        const shaftY = -24;

        // Cylindrical 3-stop linear gradient
        const cylGrad = ctx.createLinearGradient(-shaftW / 2, 0, shaftW / 2, 0);
        cylGrad.addColorStop(0, '#1e293b'); // Dark left shadow
        cylGrad.addColorStop(0.35, '#64748b'); // Specular highlight curvature
        cylGrad.addColorStop(0.7, '#334155'); // Mid stone body
        cylGrad.addColorStop(1, '#0f172a'); // Deep right shadow
        ctx.fillStyle = cylGrad;
        ctx.strokeStyle = '#0f172a';
        ctx.lineWidth = 2.5;

        // Curved cylindrical shaft base & top
        ctx.beginPath();
        ctx.roundRect(-shaftW / 2, shaftY, shaftW, shaftH, [0, 0, 16, 16]);
        ctx.fill();
        ctx.stroke();

        // Curved masonry brick courses
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.16)';
        ctx.lineWidth = 1.2;
        [-10, 4, 16].forEach(my => {
            ctx.beginPath();
            ctx.ellipse(0, my, shaftW / 2 - 2, 5, 0, 0, Math.PI);
            ctx.stroke();
        });

        // Alternating vertical brick seams
        ctx.strokeRect(-16, -10, 14, 14);
        ctx.strokeRect(6, -10, 14, 14);
        ctx.strokeRect(-8, 4, 16, 12);

        // --- DYNAMIC WALL CRACKS BASED ON HP ---
        const hpPct = tower.hp / tower.maxHp;
        if (hpPct <= 0.75) {
            ctx.strokeStyle = '#0f172a';
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.moveTo(-10, -18);
            ctx.lineTo(-4, -6);
            ctx.lineTo(-8, 4);
            ctx.stroke();
        }
        if (hpPct <= 0.40) {
            ctx.strokeStyle = '#000';
            ctx.lineWidth = 2.5;
            ctx.beginPath();
            ctx.moveTo(8, -12);
            ctx.lineTo(14, -2);
            ctx.lineTo(6, 8);
            ctx.stroke();
            // Missing brick chip
            ctx.fillStyle = '#0f172a';
            ctx.fillRect(4, 2, 6, 6);
        }

        // --- 3. BATTLEMENTS & CORNICE CORBELS ---
        // Flared stone cornice
        ctx.fillStyle = '#64748b';
        ctx.fillRect(-shaftW / 2 - 5, shaftY - 6, shaftW + 10, 7);
        ctx.strokeStyle = '#1e293b';
        ctx.strokeRect(-shaftW / 2 - 5, shaftY - 6, shaftW + 10, 7);

        // Corbels (supporting stone brackets)
        ctx.fillStyle = '#334155';
        [-22, -11, 0, 11, 22].forEach(cx => {
            ctx.beginPath();
            ctx.moveTo(cx - 3, shaftY - 1);
            ctx.lineTo(cx + 3, shaftY - 1);
            ctx.lineTo(cx, shaftY + 4);
            ctx.closePath();
            ctx.fill();
        });

        // 4 Isometric Crenellations (merlons & embrasures)
        const merlonW = 10;
        const merlonH = 12;
        const crenelY = shaftY - 18;
        const crenelPositions = [-30, -13, 4, 21];

        crenelPositions.forEach(mx => {
            ctx.fillStyle = '#475569';
            ctx.fillRect(mx, crenelY, merlonW, merlonH);
            ctx.strokeStyle = '#1e293b';
            ctx.strokeRect(mx, crenelY, merlonW, merlonH);

            // Lit top face
            ctx.fillStyle = '#94a3b8';
            ctx.fillRect(mx + 1, crenelY, merlonW - 2, 3);
        });

        // Dark interior floor depth behind battlements
        ctx.fillStyle = '#1e293b';
        ctx.beginPath();
        ctx.ellipse(0, shaftY - 8, 22, 6, 0, 0, Math.PI * 2);
        ctx.fill();

        // --- 4. TEAM SPIRE ROOF & WAVING CLOTH BANNER ---
        // Conical Tiled Roof
        const teamColor = (isFriendly && myTeam === 'blue') || (!isFriendly && myTeam === 'red') ? '#2563eb' : '#dc2626';
        const teamColorDark = (isFriendly && myTeam === 'blue') || (!isFriendly && myTeam === 'red') ? '#1d4ed8' : '#991b1b';

        const roofGrad = ctx.createLinearGradient(-18, 0, 18, 0);
        roofGrad.addColorStop(0, teamColorDark);
        roofGrad.addColorStop(0.4, '#fff');
        roofGrad.addColorStop(0.5, teamColor);
        roofGrad.addColorStop(1, teamColorDark);
        ctx.fillStyle = roofGrad;

        const spireTopY = shaftY - 34;
        ctx.beginPath();
        ctx.moveTo(0, spireTopY);
        ctx.lineTo(-20, shaftY - 8);
        ctx.lineTo(20, shaftY - 8);
        ctx.closePath();
        ctx.fill();
        ctx.strokeStyle = '#0f172a';
        ctx.lineWidth = 1.5;
        ctx.stroke();

        // Golden Spire Finial
        ctx.fillStyle = '#f59e0b';
        ctx.beginPath();
        ctx.arc(0, spireTopY - 2, 4, 0, Math.PI * 2);
        ctx.fill();

        // Flag Pole & Waving Pennant Banner
        const flagPoleTop = spireTopY - 22;
        ctx.strokeStyle = '#d97706';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(0, spireTopY);
        ctx.lineTo(0, flagPoleTop);
        ctx.stroke();

        // Animated waving banner cloth
        const wave = Math.sin(time * 6 + tower.index) * 4;
        ctx.fillStyle = teamColor;
        ctx.beginPath();
        ctx.moveTo(0, flagPoleTop);
        ctx.quadraticCurveTo(12, flagPoleTop + wave, 22, flagPoleTop + 6);
        ctx.lineTo(0, flagPoleTop + 12);
        ctx.closePath();
        ctx.fill();

        // --- 5. GLOWING ARCANE CREST ON TOWER FACE ---
        const gemY = shaftY + 16;
        // Gilded bezel frame
        ctx.fillStyle = '#f59e0b';
        ctx.beginPath();
        ctx.arc(0, gemY, 9, 0, Math.PI * 2);
        ctx.fill();

        // Pulsing Gemstone
        const gemColor = isFriendly ? '#38bdf8' : '#ef4444';
        const pulse = 0.85 + Math.sin(time * 4) * 0.15;
        ctx.fillStyle = gemColor;
        ctx.beginPath();
        ctx.arc(0, gemY, 6 * pulse, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = '#fff';
        ctx.beginPath();
        ctx.arc(-2, gemY - 2, 2, 0, Math.PI * 2);
        ctx.fill();

        // --- 6. ACTIVE BUFFS & DEFENSE RINDS ---
        const now = performance.now() / 1000;

        // Shield Energy Dome
        if (tower.shieldUntil > now) {
            ctx.save();
            ctx.strokeStyle = 'rgba(56, 189, 248, 0.9)';
            ctx.fillStyle = 'rgba(56, 189, 248, 0.22)';
            ctx.lineWidth = 3;
            ctx.shadowColor = '#38bdf8';
            ctx.shadowBlur = 16;
            ctx.beginPath();
            ctx.arc(0, -6, tower.radius + 18, 0, Math.PI * 2);
            ctx.fill();
            ctx.stroke();

            // Hexagonal shield grid
            ctx.rotate(time * 1.5);
            ctx.strokeStyle = 'rgba(255, 255, 255, 0.5)';
            ctx.lineWidth = 1.5;
            ctx.strokeRect(-24, -24, 48, 48);
            ctx.restore();
        }

        // Mirror Ward Lightning Ring
        if (tower.counterUntil > now) {
            ctx.save();
            ctx.strokeStyle = '#facc15';
            ctx.lineWidth = 3;
            ctx.shadowColor = '#eab308';
            ctx.shadowBlur = 14;
            ctx.beginPath();
            ctx.arc(0, -6, tower.radius + 14, 0, Math.PI * 2);
            ctx.stroke();
            ctx.restore();
        }

        // --- 7. CLASH ROYALE FLOATING HP BADGE ---
        renderTowerHPBar(tower, hpPct);

        ctx.restore();
    }

    function renderTowerHPBar(tower, hpPct) {
        const barW = 56;
        const barH = 8;
        const barY = -68;

        // HP Bar Drop Shadow
        ctx.fillStyle = 'rgba(0, 0, 0, 0.5)';
        ctx.fillRect(-barW / 2 + 1, barY + 1, barW, barH);

        // Dark Metallic Casing
        ctx.fillStyle = '#0f172a';
        ctx.fillRect(-barW / 2, barY, barW, barH);
        ctx.strokeStyle = '#e2e8f0';
        ctx.lineWidth = 1.2;
        ctx.strokeRect(-barW / 2, barY, barW, barH);

        // Segmented Dynamic HP Color
        const hpColor = hpPct > 0.5 ? '#22c55e' : (hpPct > 0.25 ? '#eab308' : '#ef4444');
        const fillW = Math.max(0, (barW - 2) * hpPct);
        ctx.fillStyle = hpColor;
        ctx.fillRect(-barW / 2 + 1, barY + 1, fillW, barH - 2);

        // Glass reflection sheen on top half
        ctx.fillStyle = 'rgba(255, 255, 255, 0.35)';
        ctx.fillRect(-barW / 2 + 1, barY + 1, fillW, (barH - 2) / 2);

        // Embossed HP Text
        ctx.fillStyle = '#fff';
        ctx.font = '900 9px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.shadowColor = '#000';
        ctx.shadowBlur = 3;
        ctx.fillText(`${Math.round(tower.hp)}`, 0, barY - 7);
        ctx.shadowBlur = 0;
    }

    // ==========================================
    // 3. SLINGSHOT RETICLE & JUICY TRAJECTORY
    // ==========================================
    function renderSlingshotAim() {
        if (!armedTower || !aimDragPos) return;

        const origin = { x: armedTower.x, y: armedTower.y - 36 };
        const pull = { x: aimDragPos.x - origin.x, y: aimDragPos.y - origin.y };
        const card = armedTower.activeCard;

        // Ground Arcane Targeting Circle under tower
        ctx.save();
        ctx.translate(armedTower.x, armedTower.y + 10);
        ctx.rotate(globalTime * 2);
        ctx.strokeStyle = 'rgba(245, 158, 11, 0.65)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(0, 0, 38, 0, Math.PI * 2);
        ctx.stroke();
        for (let i = 0; i < 4; i++) {
            ctx.rotate(Math.PI / 2);
            ctx.fillStyle = '#f59e0b';
            ctx.fillRect(36, -2, 5, 4);
        }
        ctx.restore();

        // Dynamic Slingshot Elastic Bands
        ctx.strokeStyle = '#f59e0b';
        ctx.lineWidth = 3.5;
        ctx.beginPath();
        ctx.moveTo(origin.x - 18, origin.y);
        ctx.lineTo(aimDragPos.x, aimDragPos.y);
        ctx.lineTo(origin.x + 18, origin.y);
        ctx.stroke();

        // Armed Projectile in Pouch
        ctx.fillStyle = card.color || '#fff';
        ctx.shadowColor = card.color || '#fff';
        ctx.shadowBlur = 10;
        ctx.beginPath();
        ctx.arc(aimDragPos.x, aimDragPos.y, 14, 0, Math.PI * 2);
        ctx.fill();
        ctx.shadowBlur = 0;

        // Parabolic Ballistic Trajectory Simulation
        const impulse = 16.5 * (card.id === 'stones' ? 1.35 : (card.id === 'counter' ? 2.0 : 1.15));
        const vx = -pull.x * impulse;
        const vy = -pull.y * impulse;
        const gravity = card.id === 'stones' ? 780 : (card.id === 'counter' ? 120 : 650);

        let simX = origin.x;
        let simY = origin.y;
        let simVy = vy;
        const dtSim = 0.032;

        for (let step = 0; step < 18; step++) {
            simX += vx * dtSim;
            simY += simVy * dtSim;
            simVy += gravity * dtSim;

            const alpha = Math.max(0.2, 1.0 - (step / 18) * 0.7);
            ctx.fillStyle = `rgba(250, 204, 21, ${alpha})`;
            ctx.beginPath();
            ctx.arc(simX, simY, Math.max(2.5, 6 - step * 0.22), 0, Math.PI * 2);
            ctx.fill();
        }

        // Highlight nearest opponent tower with lock-on crosshair
        const nearestOpp = oppTowers.find(t => !t.isDestroyed && Math.abs(t.x - (origin.x + vx * 0.45)) < 65);
        if (nearestOpp) {
            ctx.save();
            ctx.translate(nearestOpp.x, nearestOpp.y);
            ctx.strokeStyle = '#ef4444';
            ctx.lineWidth = 2.5;
            ctx.beginPath();
            ctx.arc(0, 0, nearestOpp.radius + 18, 0, Math.PI * 2);
            ctx.stroke();
            ctx.restore();
        }
    }

    // ==========================================
    // 4. 3D SHADED PROJECTILES & TRAILS
    // ==========================================
    function renderProjectiles() {
        projectiles.forEach(p => {
            ctx.save();
            ctx.translate(p.x, p.y);

            if (p.card.id === 'stones') {
                // Rotating 3D Faceted Granite Boulder
                ctx.rotate(p.rotation);
                const bGrad = ctx.createRadialGradient(-4, -4, 2, 0, 0, 15);
                bGrad.addColorStop(0, '#a8a29e');
                bGrad.addColorStop(0.5, '#78716c');
                bGrad.addColorStop(1, '#292524');
                ctx.fillStyle = bGrad;
                ctx.strokeStyle = '#1c1917';
                ctx.lineWidth = 2;

                // Faceted stone polygon
                ctx.beginPath();
                ctx.moveTo(-12, -6);
                ctx.lineTo(-6, -14);
                ctx.lineTo(8, -13);
                ctx.lineTo(15, -4);
                ctx.lineTo(13, 8);
                ctx.lineTo(3, 15);
                ctx.lineTo(-10, 12);
                ctx.closePath();
                ctx.fill();
                ctx.stroke();

                // Glowing orange fissure crack
                ctx.strokeStyle = '#f59e0b';
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                ctx.moveTo(-4, -8);
                ctx.lineTo(2, 2);
                ctx.lineTo(-2, 8);
                ctx.stroke();

            } else if (p.card.id === 'fireball') {
                // Volumetric Blazing Comet
                const fireGrad = ctx.createRadialGradient(0, 0, 2, 0, 0, 18);
                fireGrad.addColorStop(0, '#fef08a');
                fireGrad.addColorStop(0.4, '#f97316');
                fireGrad.addColorStop(0.8, '#ef4444');
                fireGrad.addColorStop(1, 'rgba(239, 68, 68, 0)');
                ctx.fillStyle = fireGrad;
                ctx.beginPath();
                ctx.arc(0, 0, 18, 0, Math.PI * 2);
                ctx.fill();

            } else if (p.card.id === 'arrows') {
                // Sleek wooden arrow with steel broadhead & fletching
                const angle = Math.atan2(p.vy, p.vx);
                ctx.rotate(angle);

                // Wood shaft
                ctx.strokeStyle = '#78350f';
                ctx.lineWidth = 2.5;
                ctx.beginPath();
                ctx.moveTo(-16, 0);
                ctx.lineTo(14, 0);
                ctx.stroke();

                // Steel broadhead tip
                ctx.fillStyle = '#e2e8f0';
                ctx.beginPath();
                ctx.moveTo(18, 0);
                ctx.lineTo(10, -4);
                ctx.lineTo(10, 4);
                ctx.closePath();
                ctx.fill();

                // Cyan feather fletching
                ctx.fillStyle = '#38bdf8';
                ctx.fillRect(-16, -3, 6, 2);
                ctx.fillRect(-16, 1, 6, 2);

            } else {
                // Electric Spear (Counterattack)
                ctx.fillStyle = '#fde047';
                ctx.shadowColor = '#eab308';
                ctx.shadowBlur = 8;
                ctx.beginPath();
                ctx.arc(0, 0, 10, 0, Math.PI * 2);
                ctx.fill();
                ctx.shadowBlur = 0;
            }

            ctx.restore();
        });
    }

    // ==========================================
    // 5. GLASS ELIXIR TUBE & PROCEDURAL CARDS
    // ==========================================
    function renderBottomDock() {
        const time = globalTime;

        // Bottom Dock Frame (Dark Obsidian with Gilded Rim)
        ctx.fillStyle = 'rgba(15, 23, 42, 0.96)';
        ctx.fillRect(0, 665, LOGICAL_W, 135);

        ctx.strokeStyle = 'rgba(245, 158, 11, 0.35)';
        ctx.lineWidth = 1.5;
        ctx.strokeRect(0, 665, LOGICAL_W, 135);

        // --- 1. GLASS ELIXIR TUBE ---
        const tubeX = 16;
        const tubeY = 672;
        const tubeW = LOGICAL_W - 32;
        const tubeH = 20;

        // Steampunk brass casing
        ctx.fillStyle = '#1e1b4b';
        ctx.fillRect(tubeX, tubeY, tubeW, tubeH);

        // Animated oscillating purple elixir fluid
        const elixirPct = Math.min(1.0, currentElixir / MAX_ELIXIR);
        const fillW = tubeW * elixirPct;

        if (fillW > 0) {
            const fluidGrad = ctx.createLinearGradient(tubeX, 0, tubeX + fillW, 0);
            fluidGrad.addColorStop(0, '#7e22ce');
            fluidGrad.addColorStop(0.5, '#a855f7');
            fluidGrad.addColorStop(1, '#c084fc');
            ctx.fillStyle = fluidGrad;

            // Dual sine wave fluid surface
            ctx.beginPath();
            ctx.moveTo(tubeX, tubeY + tubeH);
            ctx.lineTo(tubeX, tubeY);
            for (let x = 0; x <= fillW; x += 4) {
                const waveY = tubeY + Math.sin(time * 4 + x * 0.08) * 1.5;
                ctx.lineTo(tubeX + x, waveY);
            }
            ctx.lineTo(tubeX + fillW, tubeY + tubeH);
            ctx.closePath();
            ctx.fill();
        }

        // Capacity Tick Marks (0 to 10)
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.25)';
        ctx.lineWidth = 1;
        for (let i = 1; i < 10; i++) {
            const tx = tubeX + (tubeW / 10) * i;
            ctx.beginPath();
            ctx.moveTo(tx, tubeY);
            ctx.lineTo(tx, tubeY + tubeH);
            ctx.stroke();
        }

        // Glass tube highlight sheen
        ctx.fillStyle = 'rgba(255, 255, 255, 0.22)';
        ctx.fillRect(tubeX, tubeY, tubeW, tubeH / 2.5);

        // Brass Frame Outer Border
        ctx.strokeStyle = '#d97706';
        ctx.lineWidth = 1.5;
        ctx.strokeRect(tubeX, tubeY, tubeW, tubeH);

        // Embossed Elixir Quantity Label
        ctx.fillStyle = '#fff';
        ctx.font = '900 11px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.shadowColor = '#000';
        ctx.shadowBlur = 4;
        ctx.fillText(`⚡ ${Math.floor(currentElixir)} / ${MAX_ELIXIR}`, LOGICAL_W / 2, tubeY + tubeH / 2 + 1);
        ctx.shadowBlur = 0;

        // --- 2. 6 PROCEDURAL VECTOR CARDS ---
        const cardW = 58;
        const cardH = 88;
        const startX = 14;
        const spacing = 7;
        const cardY = 700;

        CARDS.forEach((card, idx) => {
            const cx = startX + idx * (cardW + spacing);
            const canAfford = currentElixir >= card.cost;

            ctx.save();
            ctx.translate(cx, cardY);

            // Shimmering Golden Border if Playable
            if (canAfford) {
                const borderPulse = 0.5 + Math.sin(time * 6 + idx) * 0.5;
                ctx.strokeStyle = `rgba(250, 204, 21, ${borderPulse})`;
                ctx.lineWidth = 2.5;
                ctx.shadowColor = '#f59e0b';
                ctx.shadowBlur = 8;
            } else {
                ctx.strokeStyle = '#334155';
                ctx.lineWidth = 1;
            }

            // Card Body (Dark Gradient)
            const cGrad = ctx.createLinearGradient(0, 0, 0, cardH);
            cGrad.addColorStop(0, '#1e1b4b');
            cGrad.addColorStop(1, '#0f172a');
            ctx.fillStyle = cGrad;
            ctx.fillRect(0, 0, cardW, cardH);
            ctx.strokeRect(0, 0, cardW, cardH);
            ctx.shadowBlur = 0;

            // Render Procedural Vector Card Art
            renderCardVectorArt(card, cardW, cardH);

            // Card Name Banner
            ctx.fillStyle = canAfford ? '#f8fafc' : '#64748b';
            ctx.font = 'bold 9px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText(card.name, cardW / 2, cardH - 8);

            // Elixir Drop Cost Badge (Top Left)
            renderElixirCostDrop(card.cost, 10, 11);

            // Lock Overlay if unaffordable
            if (!canAfford) {
                ctx.fillStyle = 'rgba(15, 23, 42, 0.65)';
                ctx.fillRect(0, 0, cardW, cardH);

                ctx.fillStyle = '#94a3b8';
                ctx.font = '12px sans-serif';
                ctx.fillText('🔒', cardW / 2, cardH / 2 + 10);
            }

            ctx.restore();
        });

        // 3. Render Card Being Dragged under finger (Scale-up + Shadow)
        if (draggingCard) {
            ctx.save();
            ctx.translate(dragPos.x, dragPos.y);
            ctx.scale(1.15, 1.15);

            ctx.fillStyle = 'rgba(0, 0, 0, 0.45)';
            ctx.fillRect(-cardW / 2 + 4, -cardH / 2 + 4, cardW, cardH);

            ctx.fillStyle = '#1e1b4b';
            ctx.strokeStyle = '#38bdf8';
            ctx.lineWidth = 3;
            ctx.fillRect(-cardW / 2, -cardH / 2, cardW, cardH);
            ctx.strokeRect(-cardW / 2, -cardH / 2, cardW, cardH);

            renderCardVectorArt(draggingCard, cardW, cardH, true);
            renderElixirCostDrop(draggingCard.cost, -cardW / 2 + 10, -cardH / 2 + 11);

            ctx.restore();
        }
    }

    // Procedural Vector Illustrations for all 6 Cards
    function renderCardVectorArt(card, w, h, isDragging = false) {
        ctx.save();
        const cx = isDragging ? 0 : w / 2;
        const cy = isDragging ? -4 : 40;

        switch (card.id) {
            case 'arrows':
                // Golden recurve bow with 3 cyan arrows
                ctx.strokeStyle = '#f59e0b';
                ctx.lineWidth = 2.5;
                ctx.beginPath();
                ctx.arc(cx - 8, cy, 14, -Math.PI * 0.4, Math.PI * 0.4);
                ctx.stroke();

                // 3 Cyan Arrows
                [-0.2, 0, 0.2].forEach(angle => {
                    ctx.save();
                    ctx.translate(cx, cy);
                    ctx.rotate(angle);
                    ctx.strokeStyle = '#38bdf8';
                    ctx.lineWidth = 2;
                    ctx.beginPath();
                    ctx.moveTo(-10, 0);
                    ctx.lineTo(12, 0);
                    ctx.stroke();

                    // Arrowhead
                    ctx.fillStyle = '#e0f2fe';
                    ctx.beginPath();
                    ctx.moveTo(14, 0);
                    ctx.lineTo(8, -3);
                    ctx.lineTo(8, 3);
                    ctx.closePath();
                    ctx.fill();
                    ctx.restore();
                });
                break;

            case 'shield':
                // Hexagonal crystalline aegis with glowing rune
                ctx.fillStyle = '#0284c7';
                ctx.strokeStyle = '#38bdf8';
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.moveTo(cx, cy - 14);
                ctx.lineTo(cx + 12, cy - 7);
                ctx.lineTo(cx + 12, cy + 7);
                ctx.lineTo(cx, cy + 14);
                ctx.lineTo(cx - 12, cy + 7);
                ctx.lineTo(cx - 12, cy - 7);
                ctx.closePath();
                ctx.fill();
                ctx.stroke();

                // Inner gem
                ctx.fillStyle = '#e0f2fe';
                ctx.beginPath();
                ctx.arc(cx, cy, 4, 0, Math.PI * 2);
                ctx.fill();
                break;

            case 'stones':
                // Heavy faceted granite boulder with glowing runes
                ctx.fillStyle = '#78716c';
                ctx.strokeStyle = '#292524';
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.arc(cx, cy, 14, 0, Math.PI * 2);
                ctx.fill();
                ctx.stroke();

                ctx.strokeStyle = '#f59e0b';
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                ctx.moveTo(cx - 6, cy - 6);
                ctx.lineTo(cx, cy + 2);
                ctx.lineTo(cx + 6, cy - 2);
                ctx.stroke();
                break;

            case 'repair':
                // Crossed master hammer & wrench with green leaves
                ctx.strokeStyle = '#f59e0b';
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.moveTo(cx - 10, cy - 10);
                ctx.lineTo(cx + 10, cy + 10);
                ctx.moveTo(cx + 10, cy - 10);
                ctx.lineTo(cx - 10, cy + 10);
                ctx.stroke();

                ctx.fillStyle = '#22c55e';
                ctx.beginPath();
                ctx.arc(cx, cy, 5, 0, Math.PI * 2);
                ctx.fill();
                break;

            case 'fireball':
                // Blazing inferno orb with solar flare ring
                const fGrad = ctx.createRadialGradient(cx, cy, 2, cx, cy, 14);
                fGrad.addColorStop(0, '#fef08a');
                fGrad.addColorStop(0.5, '#f97316');
                fGrad.addColorStop(1, '#ef4444');
                ctx.fillStyle = fGrad;
                ctx.beginPath();
                ctx.arc(cx, cy, 14, 0, Math.PI * 2);
                ctx.fill();
                break;

            case 'counter':
                // Spiked golden shield with lightning bolts
                ctx.fillStyle = '#eab308';
                ctx.beginPath();
                ctx.arc(cx, cy, 12, 0, Math.PI * 2);
                ctx.fill();

                ctx.strokeStyle = '#fff';
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.moveTo(cx - 4, cy - 8);
                ctx.lineTo(cx + 2, cy - 1);
                ctx.lineTo(cx - 2, cy + 1);
                ctx.lineTo(cx + 4, cy + 8);
                ctx.stroke();
                break;
        }

        ctx.restore();
    }

    function renderElixirCostDrop(cost, x, y) {
        ctx.save();
        // Glossy purple drop
        ctx.fillStyle = '#a855f7';
        ctx.beginPath();
        ctx.arc(x, y + 2, 7, 0, Math.PI * 2);
        ctx.fill();
        ctx.beginPath();
        ctx.moveTo(x - 6, y);
        ctx.lineTo(x, y - 8);
        ctx.lineTo(x + 6, y);
        ctx.fill();

        ctx.fillStyle = '#fff';
        ctx.font = '900 10px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(`${cost}`, x, y + 2);
        ctx.restore();
    }

    // ==========================================
    // 6. PARTICLES, SHOCKWAVES & DEBRIS
    // ==========================================
    function renderShockwaves() {
        shockwaves.forEach(sw => {
            ctx.save();
            ctx.strokeStyle = `rgba(255, 255, 255, ${sw.alpha})`;
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.arc(sw.x, sw.y, sw.r, 0, Math.PI * 2);
            ctx.stroke();
            ctx.restore();
        });
    }

    function renderDebrisBlocks() {
        debrisBlocks.forEach(d => {
            ctx.save();
            ctx.translate(d.x, d.y);
            ctx.rotate(d.rot);
            ctx.fillStyle = d.color;
            ctx.fillRect(-d.size / 2, -d.size / 2, d.size, d.size);
            ctx.restore();
        });
    }

    function renderParticles() {
        particles.forEach(pt => {
            ctx.save();
            ctx.globalAlpha = pt.alpha;
            ctx.fillStyle = pt.color;
            ctx.beginPath();
            ctx.arc(pt.x, pt.y, pt.size, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();
        });
    }

    function renderFloatingTexts() {
        floatingTexts.forEach(ft => {
            ctx.save();
            ctx.globalAlpha = ft.alpha;
            ctx.translate(ft.x, ft.y);
            ctx.scale(ft.scale, ft.scale);
            ctx.fillStyle = ft.color;
            ctx.font = '900 15px sans-serif';
            ctx.textAlign = 'center';
            ctx.shadowColor = '#000';
            ctx.shadowBlur = 5;
            ctx.fillText(ft.text, 0, 0);
            ctx.restore();
        });
    }

    function createTrailParticle(p) {
        particles.push({
            x: p.x + (Math.random() - 0.5) * 6,
            y: p.y + (Math.random() - 0.5) * 6,
            vx: (Math.random() - 0.5) * 15,
            vy: (Math.random() - 0.5) * 15,
            size: p.card.id === 'fireball' ? 6 : 3,
            color: p.card.color || '#fff',
            alpha: 0.8,
            age: 0,
            life: p.card.id === 'fireball' ? 0.35 : 0.2
        });
    }

    function createArrowBurst(x, y) {
        for (let i = 0; i < 16; i++) {
            const angle = Math.random() * Math.PI * 2;
            const spd = 40 + Math.random() * 90;
            particles.push({
                x, y,
                vx: Math.cos(angle) * spd,
                vy: Math.sin(angle) * spd,
                size: 2.5,
                color: '#38bdf8',
                alpha: 1.0,
                age: 0,
                life: 0.35
            });
        }
    }

    function createStoneDebris(x, y) {
        for (let i = 0; i < 24; i++) {
            const angle = Math.random() * Math.PI * 2;
            const spd = 60 + Math.random() * 130;
            particles.push({
                x, y,
                vx: Math.cos(angle) * spd,
                vy: Math.sin(angle) * spd,
                size: 3 + Math.random() * 4,
                color: '#78716c',
                alpha: 1.0,
                age: 0,
                life: 0.55
            });
        }
    }

    function createFireExplosion(x, y) {
        for (let i = 0; i < 34; i++) {
            const angle = Math.random() * Math.PI * 2;
            const spd = 80 + Math.random() * 180;
            particles.push({
                x, y,
                vx: Math.cos(angle) * spd,
                vy: Math.sin(angle) * spd,
                size: 5 + Math.random() * 5,
                color: Math.random() < 0.5 ? '#f97316' : '#facc15',
                alpha: 1.0,
                age: 0,
                life: 0.5
            });
        }
    }

    function createShieldBurst(x, y) {
        for (let i = 0; i < 18; i++) {
            const angle = Math.random() * Math.PI * 2;
            particles.push({
                x, y,
                vx: Math.cos(angle) * 75,
                vy: Math.sin(angle) * 75,
                size: 3,
                color: '#06b6d4',
                alpha: 1.0,
                age: 0,
                life: 0.38
            });
        }
    }

    function createLightningBurst(x, y) {
        for (let i = 0; i < 22; i++) {
            const angle = Math.random() * Math.PI * 2;
            particles.push({
                x, y,
                vx: Math.cos(angle) * 120,
                vy: Math.sin(angle) * 120,
                size: 3.5,
                color: '#fde047',
                alpha: 1.0,
                age: 0,
                life: 0.32
            });
        }
    }

    function createTowerCollapseFX(x, y) {
        // Volumetric flying stone blocks
        for (let i = 0; i < 35; i++) {
            const angle = Math.random() * Math.PI * 2;
            const spd = 50 + Math.random() * 200;
            debrisBlocks.push({
                x, y,
                vx: Math.cos(angle) * spd,
                vy: Math.sin(angle) * spd - 120,
                size: 5 + Math.random() * 7,
                rot: Math.random() * Math.PI,
                vRot: (Math.random() - 0.5) * 12,
                color: Math.random() < 0.5 ? '#475569' : '#334155',
                life: 1.2
            });
        }

        // Fire & smoke plumes
        for (let i = 0; i < 40; i++) {
            const angle = Math.random() * Math.PI * 2;
            const spd = 30 + Math.random() * 120;
            particles.push({
                x, y,
                vx: Math.cos(angle) * spd,
                vy: Math.sin(angle) * spd - 60,
                size: 6 + Math.random() * 8,
                color: Math.random() < 0.4 ? '#f97316' : '#292524',
                alpha: 1.0,
                age: 0,
                life: 0.9
            });
        }
    }

    function createSmokePuff(x, y) {
        particles.push({
            x, y,
            vx: (Math.random() - 0.5) * 12,
            vy: -15 - Math.random() * 20,
            size: 4 + Math.random() * 4,
            color: '#64748b',
            alpha: 0.7,
            age: 0,
            life: 0.65
        });
    }

    function createSparkle(x, y, color) {
        particles.push({
            x, y,
            vx: (Math.random() - 0.5) * 12,
            vy: -20 - Math.random() * 32,
            size: 3,
            color,
            alpha: 1.0,
            age: 0,
            life: 0.55
        });
    }

    function showFloatingText(x, y, text, color) {
        floatingTexts.push({
            x, y, text, color,
            scale: 1.3,
            alpha: 1.0,
            age: 0,
            life: 0.8
        });
    }

    // --- INPUT CONTROLS ---
    function setupInputHandlers() {
        const onStart = (e) => {
            window.sound.ensureContext();
            const pos = getLogicalCoords(e);

            if (armedTower) {
                aimDragPos = pos;
                return;
            }

            // Check if card tapped in bottom tray (y in [698, 792])
            if (pos.y >= 695 && pos.y <= 795) {
                const cardW = 58;
                const spacing = 7;
                const startX = 14;

                CARDS.forEach((card, idx) => {
                    const cx = startX + idx * (cardW + spacing);
                    if (pos.x >= cx && pos.x <= cx + cardW) {
                        if (currentElixir >= card.cost) {
                            draggingCard = card;
                            dragPos = pos;
                            window.sound.vibrate([15]);
                        } else {
                            showNotification(`Need ${card.cost} Elixir!`);
                        }
                    }
                });
            }
        };

        const onMove = (e) => {
            const pos = getLogicalCoords(e);

            if (armedTower) {
                aimDragPos = pos;
                const pullDist = Math.hypot(pos.x - armedTower.x, pos.y - armedTower.y);
                window.sound.playSlingshotTick(Math.min(1.0, pullDist / 80));
                return;
            }

            if (draggingCard) {
                dragPos = pos;
            }
        };

        const onEnd = (e) => {
            // Slingshot launch
            if (armedTower && aimDragPos) {
                const origin = { x: armedTower.x, y: armedTower.y - 36 };
                const pull = { x: aimDragPos.x - origin.x, y: aimDragPos.y - origin.y };
                const pullDist = Math.hypot(pull.x, pull.y);

                if (pullDist > 18) {
                    launchArmedProjectile(armedTower, armedTower.activeCard, pull);
                } else {
                    showNotification('Aim Cancelled');
                    armedTower.activeCard = null;
                }
                armedTower = null;
                aimDragPos = null;
                return;
            }

            // Card drop onto tower
            if (draggingCard) {
                let dropped = false;
                for (const tower of myTowers) {
                    if (tower.isDestroyed) continue;
                    const dist = Math.hypot(dragPos.x - tower.x, dragPos.y - tower.y);
                    if (dist <= 65) {
                        tryApplyCard(draggingCard, tower);
                        dropped = true;
                        break;
                    }
                }

                if (!dropped) {
                    window.sound.vibrate([20]);
                }
                draggingCard = null;
            }
        };

        // Touch events with passive: false to block browser scroll
        canvas.addEventListener('touchstart', (e) => { e.preventDefault(); onStart(e); }, { passive: false });
        canvas.addEventListener('touchmove', (e) => { e.preventDefault(); onMove(e); }, { passive: false });
        canvas.addEventListener('touchend', (e) => { e.preventDefault(); onEnd(e); }, { passive: false });
        canvas.addEventListener('touchcancel', (e) => { e.preventDefault(); onEnd(e); }, { passive: false });

        // Mouse events for desktop browser testing
        let isMouseDown = false;
        canvas.addEventListener('mousedown', (e) => { isMouseDown = true; onStart(e); });
        canvas.addEventListener('mousemove', (e) => { if (isMouseDown) onMove(e); });
        canvas.addEventListener('mouseup', (e) => { isMouseDown = false; onEnd(e); });
    }

    // --- SOLO AI BOT SYSTEM ---
    let aiTimer = 0;
    let aiElixir = 4.0;

    function startSoloAI() {
        isSoloAI = true;
        myRole = 'playerA';
        myTeam = 'blue';
        updateHUDStatus();
        showWaitingModal(false);
        hideGameOverModal();
        resetBattleState();
        state = 'BATTLE';
        showNotification('🤖 SOLO PRACTICE VS BOT');
    }

    function updateSoloAI(dt) {
        aiElixir = Math.min(MAX_ELIXIR, aiElixir + dt * ELIXIR_RECHARGE_RATE);
        aiTimer += dt;

        if (aiTimer >= 3.2) {
            aiTimer = 0;
            const liveOppTowers = oppTowers.filter(t => !t.isDestroyed);
            if (liveOppTowers.length === 0) return;

            const castingTower = liveOppTowers[Math.floor(Math.random() * liveOppTowers.length)];

            // AI Decision: Heal if damaged, or attack
            if (castingTower.hp < 300 && aiElixir >= 4) {
                aiElixir -= 4;
                applyBuffToTower(castingTower, 'repair', false);
            } else if (castingTower.hp < 200 && aiElixir >= 3) {
                aiElixir -= 3;
                applyBuffToTower(castingTower, 'shield', false);
            } else if (aiElixir >= 4) {
                const attackCard = Math.random() < 0.5 ? CARDS[2] : (Math.random() < 0.5 ? CARDS[4] : CARDS[0]); // Stones, Fireball, or Arrows
                if (aiElixir >= attackCard.cost) {
                    aiElixir -= attackCard.cost;
                    const liveTargets = myTowers.filter(t => !t.isDestroyed);
                    if (liveTargets.length > 0) {
                        const target = liveTargets[Math.floor(Math.random() * liveTargets.length)];
                        const dx = (target.x - castingTower.x) * 1.0;
                        const dy = (target.y - castingTower.y) * 0.95;
                        createProjectile(attackCard, { x: castingTower.x, y: castingTower.y + 30 }, { x: dx * 1.5, y: dy * 1.4 }, false);
                        window.sound.playWhoosh();
                    }
                }
            }
        }
    }

    // --- UI HELPERS & MODALS ---
    function updateHUDStatus() {
        if (isSoloAI) {
            hudRoleText.textContent = 'SOLO BOT MODE';
            hudTeamDot.className = 'team-dot team-blue';
        } else if (myRole === 'playerA') {
            hudRoleText.textContent = 'PLAYER A (BLUE)';
            hudTeamDot.className = 'team-dot team-blue';
        } else if (myRole === 'playerB') {
            hudRoleText.textContent = 'PLAYER B (RED)';
            hudTeamDot.className = 'team-dot team-red';
        } else {
            hudRoleText.textContent = 'SPECTATOR';
            hudTeamDot.className = 'team-dot';
        }
    }

    function showNotification(text) {
        notificationBanner.textContent = text;
        notificationBanner.classList.add('visible');
        clearTimeout(notificationBanner._timer);
        notificationBanner._timer = setTimeout(() => {
            notificationBanner.classList.remove('visible');
        }, 1800);
    }

    function showWaitingModal(show) {
        if (show) {
            modalWaiting.classList.remove('hidden');
        } else {
            modalWaiting.classList.add('hidden');
        }
    }

    function showGameOverModal(won) {
        modalGameOver.classList.remove('hidden');
        if (won) {
            gameoverTitle.textContent = 'VICTORY!';
            gameoverSubtitle.textContent = 'You shattered the enemy fortress!';
            window.sound.playVictory();
        } else {
            gameoverTitle.textContent = 'DEFEAT';
            gameoverSubtitle.textContent = 'Your castle towers have fallen.';
            window.sound.playDefeat();
        }
    }

    function hideGameOverModal() {
        modalGameOver.classList.add('hidden');
    }

    function setupUIButtons() {
        btnSoloToggle.addEventListener('click', () => {
            window.sound.init();
            startSoloAI();
        });

        btnMuteToggle.addEventListener('click', () => {
            window.sound.init();
            window.sound.isMuted = !window.sound.isMuted;
            btnMuteToggle.textContent = window.sound.isMuted ? '🔇' : '🔊';
        });

        btnSwitchSolo.addEventListener('click', () => {
            window.sound.init();
            startSoloAI();
        });

        btnPlayAgain.addEventListener('click', () => {
            window.sound.init();
            hideGameOverModal();
            if (isSoloAI) {
                resetBattleState();
                state = 'BATTLE';
                showNotification('⚔️ BATTLE COMMENCED!');
            } else {
                sendPacket({ type: 'playAgain' });
                showNotification('Rematch requested...');
            }
        });

        btnRematchSolo.addEventListener('click', () => {
            window.sound.init();
            startSoloAI();
        });
    }

    // Bootstrap
    window.addEventListener('DOMContentLoaded', init);

})();
