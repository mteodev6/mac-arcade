// Space Defender - Retro Arcade Vector Space Shooter
// Pure HTML5 Canvas & WebAudio Synthesizer (Zero external dependencies)

(function() {
    const canvas = document.getElementById('gameCanvas');
    const ctx = canvas.getContext('2d');

    // Retro WebAudio Sound Synthesizer
    let audioCtx = null;
    function initAudio() {
        if (!audioCtx) {
            audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        }
        if (audioCtx.state === 'suspended') {
            audioCtx.resume();
        }
    }

    function playSound(type) {
        if (!audioCtx) return;
        try {
            const now = audioCtx.currentTime;
            if (type === 'laser') {
                const osc = audioCtx.createOscillator();
                const gain = audioCtx.createGain();
                osc.type = 'sawtooth';
                osc.frequency.setValueAtTime(880, now);
                osc.frequency.exponentialRampToValueAtTime(110, now + 0.15);
                gain.gain.setValueAtTime(0.3, now);
                gain.gain.exponentialRampToValueAtTime(0.01, now + 0.15);
                osc.connect(gain);
                gain.connect(audioCtx.destination);
                osc.start(now);
                osc.stop(now + 0.15);
            } else if (type === 'explosion') {
                const bufferSize = audioCtx.sampleRate * 0.3;
                const buffer = audioCtx.createBuffer(1, bufferSize, audioCtx.sampleRate);
                const data = buffer.getChannelData(0);
                for (let i = 0; i < bufferSize; i++) {
                    data[i] = Math.random() * 2 - 1;
                }
                const noise = audioCtx.createBufferSource();
                noise.buffer = buffer;
                const filter = audioCtx.createBiquadFilter();
                filter.type = 'lowpass';
                filter.frequency.setValueAtTime(800, now);
                filter.frequency.exponentialRampToValueAtTime(50, now + 0.3);
                const gain = audioCtx.createGain();
                gain.gain.setValueAtTime(0.4, now);
                gain.gain.exponentialRampToValueAtTime(0.01, now + 0.3);
                noise.connect(filter);
                filter.connect(gain);
                gain.connect(audioCtx.destination);
                noise.start(now);
            } else if (type === 'powerup') {
                const notes = [440, 554, 659, 880];
                notes.forEach((freq, idx) => {
                    const osc = audioCtx.createOscillator();
                    const gain = audioCtx.createGain();
                    osc.type = 'sine';
                    osc.frequency.setValueAtTime(freq, now + idx * 0.06);
                    gain.gain.setValueAtTime(0.2, now + idx * 0.06);
                    gain.gain.exponentialRampToValueAtTime(0.01, now + idx * 0.06 + 0.1);
                    osc.connect(gain);
                    gain.connect(audioCtx.destination);
                    osc.start(now + idx * 0.06);
                    osc.stop(now + idx * 0.06 + 0.1);
                });
            } else if (type === 'ufo') {
                const osc = audioCtx.createOscillator();
                const gain = audioCtx.createGain();
                osc.type = 'triangle';
                osc.frequency.setValueAtTime(600, now);
                osc.frequency.linearRampToValueAtTime(750, now + 0.08);
                osc.frequency.linearRampToValueAtTime(600, now + 0.16);
                gain.gain.setValueAtTime(0.15, now);
                gain.gain.linearRampToValueAtTime(0.01, now + 0.16);
                osc.connect(gain);
                gain.connect(audioCtx.destination);
                osc.start(now);
                osc.stop(now + 0.16);
            }
        } catch (e) {
            console.error(e);
        }
    }

    // Game State
    let score = 0;
    let highScore = parseInt(localStorage.getItem('space_defender_high') || '0', 10);
    let lives = 3;
    let wave = 1;
    let gameState = 'START'; // START, PLAYING, GAMEOVER, PAUSED
    let isPaused = false;

    // Keys State
    const keys = {};
    window.addEventListener('keydown', e => {
        initAudio();
        keys[e.code] = true;
        if (e.code === 'KeyP') {
            togglePause();
        }
        if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) {
            e.preventDefault();
        }
    });
    window.addEventListener('keyup', e => {
        keys[e.code] = false;
    });

    // Native Mac bridge support
    window.arcadePause = () => { if (gameState === 'PLAYING') togglePause(true); };
    window.arcadeResume = () => { if (gameState === 'PLAYING') togglePause(false); };
    window.arcadeRestart = () => { resetGame(); };

    function togglePause(force) {
        if (force !== undefined) isPaused = force;
        else isPaused = !isPaused;
    }

    // Player Ship
    const ship = {
        x: canvas.width / 2,
        y: canvas.height / 2,
        r: 12,
        angle: -Math.PI / 2,
        rotation: 0,
        thrust: { x: 0, y: 0 },
        isThrusting: false,
        canShoot: true,
        shootCooldown: 0,
        invulnerableTime: 120,
        tripleShotTime: 0
    };

    // Arrays
    let lasers = [];
    let asteroids = [];
    let particles = [];
    let ufos = [];
    let powerups = [];

    function resetShip() {
        ship.x = canvas.width / 2;
        ship.y = canvas.height / 2;
        ship.thrust = { x: 0, y: 0 };
        ship.angle = -Math.PI / 2;
        ship.invulnerableTime = 150;
    }

    function resetGame() {
        score = 0;
        lives = 3;
        wave = 1;
        lasers = [];
        particles = [];
        ufos = [];
        powerups = [];
        resetShip();
        spawnAsteroids(4 + wave * 2);
        gameState = 'PLAYING';
        isPaused = false;
    }

    function spawnAsteroids(count) {
        asteroids = [];
        for (let i = 0; i < count; i++) {
            let x, y, dist;
            do {
                x = Math.random() * canvas.width;
                y = Math.random() * canvas.height;
                dist = Math.hypot(x - ship.x, y - ship.y);
            } while (dist < 150);

            asteroids.push(createAsteroid(x, y, 40));
        }
    }

    function createAsteroid(x, y, radius) {
        const points = 10 + Math.floor(Math.random() * 6);
        const offsets = [];
        for (let i = 0; i < points; i++) {
            offsets.push(0.75 + Math.random() * 0.5);
        }
        const speed = (Math.random() * 1.5 + 0.5) * (40 / radius);
        const angle = Math.random() * Math.PI * 2;
        return {
            x, y,
            radius,
            vx: Math.cos(angle) * speed,
            vy: Math.sin(angle) * speed,
            angle: 0,
            rotSpeed: (Math.random() - 0.5) * 0.04,
            points,
            offsets
        };
    }

    function spawnUfo() {
        if (ufos.length > 0 || Math.random() > 0.003) return;
        const fromLeft = Math.random() > 0.5;
        ufos.push({
            x: fromLeft ? 0 : canvas.width,
            y: 80 + Math.random() * (canvas.height - 160),
            vx: fromLeft ? 2 : -2,
            vy: (Math.random() - 0.5) * 1.5,
            shootTimer: 0
        });
        playSound('ufo');
    }

    function createExplosion(x, y, color, count = 18) {
        for (let i = 0; i < count; i++) {
            const angle = Math.random() * Math.PI * 2;
            const speed = Math.random() * 4 + 1;
            particles.push({
                x, y,
                vx: Math.cos(angle) * speed,
                vy: Math.sin(angle) * speed,
                life: 30 + Math.random() * 20,
                maxLife: 50,
                color: color || '#00f2fe'
            });
        }
    }

    // Main Update Loop
    function update() {
        if (gameState !== 'PLAYING' || isPaused) return;

        // Ship Steering
        if (keys['ArrowLeft'] || keys['KeyA']) {
            ship.angle -= 0.07;
        }
        if (keys['ArrowRight'] || keys['KeyD']) {
            ship.angle += 0.07;
        }

        // Thrust
        if (keys['ArrowUp'] || keys['KeyW']) {
            ship.isThrusting = true;
            ship.thrust.x += Math.cos(ship.angle) * 0.18;
            ship.thrust.y += Math.sin(ship.angle) * 0.18;

            // Exhaust particles
            const exX = ship.x - Math.cos(ship.angle) * ship.r * 1.2;
            const exY = ship.y - Math.sin(ship.angle) * ship.r * 1.2;
            particles.push({
                x: exX + (Math.random() - 0.5) * 4,
                y: exY + (Math.random() - 0.5) * 4,
                vx: -Math.cos(ship.angle) * 3 + (Math.random() - 0.5) * 1.5,
                vy: -Math.sin(ship.angle) * 3 + (Math.random() - 0.5) * 1.5,
                life: 12,
                maxLife: 12,
                color: '#ff007f'
            });
        } else {
            ship.isThrusting = false;
            ship.thrust.x *= 0.985;
            ship.thrust.y *= 0.985;
        }

        // Friction & Position
        ship.x += ship.thrust.x;
        ship.y += ship.thrust.y;

        // Screen wrap
        if (ship.x < 0) ship.x = canvas.width;
        else if (ship.x > canvas.width) ship.x = 0;
        if (ship.y < 0) ship.y = canvas.height;
        else if (ship.y > canvas.height) ship.y = 0;

        if (ship.invulnerableTime > 0) ship.invulnerableTime--;
        if (ship.tripleShotTime > 0) ship.tripleShotTime--;

        // Shooting
        if (ship.shootCooldown > 0) ship.shootCooldown--;
        if ((keys['Space'] || keys['KeyZ']) && ship.shootCooldown <= 0) {
            ship.shootCooldown = 12;
            playSound('laser');
            if (ship.tripleShotTime > 0) {
                [-0.2, 0, 0.2].forEach(offset => {
                    lasers.push({
                        x: ship.x + Math.cos(ship.angle) * ship.r,
                        y: ship.y + Math.sin(ship.angle) * ship.r,
                        vx: Math.cos(ship.angle + offset) * 8 + ship.thrust.x * 0.3,
                        vy: Math.sin(ship.angle + offset) * 8 + ship.thrust.y * 0.3,
                        life: 60
                    });
                });
            } else {
                lasers.push({
                    x: ship.x + Math.cos(ship.angle) * ship.r,
                    y: ship.y + Math.sin(ship.angle) * ship.r,
                    vx: Math.cos(ship.angle) * 8 + ship.thrust.x * 0.3,
                    vy: Math.sin(ship.angle) * 8 + ship.thrust.y * 0.3,
                    life: 60
                });
            }
        }

        // Update Lasers
        for (let i = lasers.length - 1; i >= 0; i--) {
            const l = lasers[i];
            l.x += l.vx;
            l.y += l.vy;
            l.life--;

            if (l.x < 0) l.x = canvas.width;
            else if (l.x > canvas.width) l.x = 0;
            if (l.y < 0) l.y = canvas.height;
            else if (l.y > canvas.height) l.y = 0;

            if (l.life <= 0) {
                lasers.splice(i, 1);
            }
        }

        // Update Asteroids
        for (let i = asteroids.length - 1; i >= 0; i--) {
            const a = asteroids[i];
            a.x += a.vx;
            a.y += a.vy;
            a.angle += a.rotSpeed;

            if (a.x < -a.radius) a.x = canvas.width + a.radius;
            else if (a.x > canvas.width + a.radius) a.x = -a.radius;
            if (a.y < -a.radius) a.y = canvas.height + a.radius;
            else if (a.y > canvas.height + a.radius) a.y = -a.radius;

            // Check collision with ship
            if (ship.invulnerableTime <= 0) {
                const dist = Math.hypot(a.x - ship.x, a.y - ship.y);
                if (dist < a.radius + ship.r) {
                    createExplosion(ship.x, ship.y, '#ff007f', 40);
                    playSound('explosion');
                    lives--;
                    if (lives <= 0) {
                        gameState = 'GAMEOVER';
                        if (score > highScore) {
                            highScore = score;
                            localStorage.setItem('space_defender_high', highScore.toString());
                        }
                    } else {
                        resetShip();
                    }
                }
            }

            // Check collision with lasers
            for (let j = lasers.length - 1; j >= 0; j--) {
                const l = lasers[j];
                const dist = Math.hypot(a.x - l.x, a.y - l.y);
                if (dist < a.radius) {
                    playSound('explosion');
                    createExplosion(a.x, a.y, '#00f2fe', 20);
                    lasers.splice(j, 1);

                    // Chance for powerup
                    if (Math.random() < 0.15) {
                        powerups.push({
                            x: a.x,
                            y: a.y,
                            type: Math.random() < 0.5 ? 'TRIPLE' : 'SHIELD',
                            life: 400
                        });
                    }

                    if (a.radius > 28) {
                        score += 50;
                        asteroids.push(createAsteroid(a.x, a.y, 20));
                        asteroids.push(createAsteroid(a.x, a.y, 20));
                    } else if (a.radius > 14) {
                        score += 100;
                        asteroids.push(createAsteroid(a.x, a.y, 10));
                        asteroids.push(createAsteroid(a.x, a.y, 10));
                    } else {
                        score += 200;
                    }

                    asteroids.splice(i, 1);
                    break;
                }
            }
        }

        // Spawn next wave if cleared
        if (asteroids.length === 0) {
            wave++;
            spawnAsteroids(4 + wave * 2);
            playSound('powerup');
        }

        // UFO
        spawnUfo();
        for (let i = ufos.length - 1; i >= 0; i--) {
            const u = ufos[i];
            u.x += u.vx;
            u.y += u.vy;

            // UFO Shooting
            u.shootTimer++;
            if (u.shootTimer > 80) {
                u.shootTimer = 0;
                const angle = Math.atan2(ship.y - u.y, ship.x - u.x);
                lasers.push({
                    x: u.x,
                    y: u.y,
                    vx: Math.cos(angle) * 5,
                    vy: Math.sin(angle) * 5,
                    life: 90,
                    isEnemy: true
                });
            }

            // Ship collision
            if (ship.invulnerableTime <= 0 && Math.hypot(u.x - ship.x, u.y - ship.y) < 25) {
                createExplosion(ship.x, ship.y, '#ff007f', 40);
                playSound('explosion');
                lives--;
                ufos.splice(i, 1);
                if (lives <= 0) {
                    gameState = 'GAMEOVER';
                } else {
                    resetShip();
                }
                continue;
            }

            // Laser collision
            for (let j = lasers.length - 1; j >= 0; j--) {
                const l = lasers[j];
                if (l.isEnemy) continue;
                if (Math.hypot(u.x - l.x, u.y - l.y) < 20) {
                    score += 500;
                    playSound('explosion');
                    createExplosion(u.x, u.y, '#ffd200', 30);
                    ufos.splice(i, 1);
                    lasers.splice(j, 1);
                    break;
                }
            }

            if (u.x < -40 || u.x > canvas.width + 40) {
                ufos.splice(i, 1);
            }
        }

        // Powerups
        for (let i = powerups.length - 1; i >= 0; i--) {
            const p = powerups[i];
            p.life--;
            if (Math.hypot(p.x - ship.x, p.y - ship.y) < 25) {
                playSound('powerup');
                if (p.type === 'TRIPLE') ship.tripleShotTime = 400;
                else if (p.type === 'SHIELD') ship.invulnerableTime = 300;
                powerups.splice(i, 1);
                continue;
            }
            if (p.life <= 0) powerups.splice(i, 1);
        }

        // Particles
        for (let i = particles.length - 1; i >= 0; i--) {
            const pt = particles[i];
            pt.x += pt.vx;
            pt.y += pt.vy;
            pt.life--;
            if (pt.life <= 0) particles.splice(i, 1);
        }
    }

    // Render Loop
    function render() {
        ctx.fillStyle = '#05060a';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        // Stars background
        ctx.fillStyle = 'rgba(255, 255, 255, 0.3)';
        for (let i = 0; i < 40; i++) {
            const sx = ((i * 137.5) % canvas.width);
            const sy = ((i * 293.3) % canvas.height);
            ctx.fillRect(sx, sy, 1.5, 1.5);
        }

        // Draw Asteroids
        ctx.lineWidth = 1.8;
        asteroids.forEach(a => {
            ctx.strokeStyle = '#00f2fe';
            ctx.shadowColor = '#00f2fe';
            ctx.shadowBlur = 8;
            ctx.beginPath();
            for (let i = 0; i < a.points; i++) {
                const angle = a.angle + (i / a.points) * Math.PI * 2;
                const r = a.radius * a.offsets[i];
                const px = a.x + Math.cos(angle) * r;
                const py = a.y + Math.sin(angle) * r;
                if (i === 0) ctx.moveTo(px, py);
                else ctx.lineTo(px, py);
            }
            ctx.closePath();
            ctx.stroke();
        });

        // Draw Lasers
        lasers.forEach(l => {
            ctx.strokeStyle = l.isEnemy ? '#ff2256' : '#00f2fe';
            ctx.shadowColor = l.isEnemy ? '#ff2256' : '#00f2fe';
            ctx.shadowBlur = 10;
            ctx.beginPath();
            ctx.arc(l.x, l.y, l.isEnemy ? 3.5 : 2.5, 0, Math.PI * 2);
            ctx.stroke();
        });

        // Draw Powerups
        powerups.forEach(p => {
            ctx.strokeStyle = p.type === 'TRIPLE' ? '#ffd200' : '#39ff14';
            ctx.shadowColor = ctx.strokeStyle;
            ctx.shadowBlur = 12;
            ctx.beginPath();
            ctx.arc(p.x, p.y, 10, 0, Math.PI * 2);
            ctx.stroke();
            ctx.fillStyle = ctx.strokeStyle;
            ctx.font = '10px Courier New';
            ctx.textAlign = 'center';
            ctx.fillText(p.type === 'TRIPLE' ? '3X' : 'S', p.x, p.y + 4);
        });

        // Draw UFOs
        ufos.forEach(u => {
            ctx.strokeStyle = '#ffd200';
            ctx.shadowColor = '#ffd200';
            ctx.shadowBlur = 12;
            ctx.beginPath();
            ctx.ellipse(u.x, u.y, 18, 7, 0, 0, Math.PI * 2);
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(u.x, u.y - 3, 7, Math.PI, 0);
            ctx.stroke();
        });

        // Draw Particles
        particles.forEach(pt => {
            ctx.fillStyle = pt.color;
            ctx.shadowColor = pt.color;
            ctx.shadowBlur = 6;
            ctx.globalAlpha = pt.life / pt.maxLife;
            ctx.fillRect(pt.x, pt.y, 2, 2);
        });
        ctx.globalAlpha = 1.0;

        // Draw Ship
        if (gameState === 'PLAYING') {
            const isFlashing = ship.invulnerableTime > 0 && Math.floor(ship.invulnerableTime / 4) % 2 === 0;
            if (!isFlashing) {
                ctx.save();
                ctx.translate(ship.x, ship.y);
                ctx.rotate(ship.angle);

                ctx.strokeStyle = '#ffffff';
                ctx.shadowColor = '#00f2fe';
                ctx.shadowBlur = 10;
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.moveTo(ship.r, 0);
                ctx.lineTo(-ship.r * 0.8, -ship.r * 0.7);
                ctx.lineTo(-ship.r * 0.4, 0);
                ctx.lineTo(-ship.r * 0.8, ship.r * 0.7);
                ctx.closePath();
                ctx.stroke();

                if (ship.isThrusting) {
                    ctx.strokeStyle = '#ff007f';
                    ctx.shadowColor = '#ff007f';
                    ctx.beginPath();
                    ctx.moveTo(-ship.r * 0.4, 0);
                    ctx.lineTo(-ship.r * 1.3, 0);
                    ctx.stroke();
                }

                if (ship.invulnerableTime > 0) {
                    ctx.strokeStyle = '#39ff14';
                    ctx.beginPath();
                    ctx.arc(0, 0, ship.r * 1.5, 0, Math.PI * 2);
                    ctx.stroke();
                }

                ctx.restore();
            }
        }

        // Draw HUD
        ctx.shadowBlur = 0;
        ctx.fillStyle = '#00f2fe';
        ctx.font = 'bold 16px "Courier New", monospace';
        ctx.textAlign = 'left';
        ctx.fillText(`SCORE: ${score}`, 20, 30);
        ctx.textAlign = 'center';
        ctx.fillText(`WAVE ${wave}`, canvas.width / 2, 30);
        ctx.textAlign = 'right';
        ctx.fillText(`HIGH: ${highScore}`, canvas.width - 20, 30);

        // Lives indicators
        for (let i = 0; i < lives; i++) {
            ctx.save();
            ctx.translate(30 + i * 20, 52);
            ctx.rotate(-Math.PI / 2);
            ctx.strokeStyle = '#ffffff';
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.moveTo(8, 0);
            ctx.lineTo(-6, -5);
            ctx.lineTo(-3, 0);
            ctx.lineTo(-6, 5);
            ctx.closePath();
            ctx.stroke();
            ctx.restore();
        }

        // Overlay Screens
        if (gameState === 'START') {
            ctx.fillStyle = 'rgba(5, 6, 10, 0.85)';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            ctx.fillStyle = '#00f2fe';
            ctx.font = 'bold 36px "Courier New", monospace';
            ctx.textAlign = 'center';
            ctx.shadowColor = '#00f2fe';
            ctx.shadowBlur = 15;
            ctx.fillText('SPACE DEFENDER', canvas.width / 2, 220);

            ctx.fillStyle = '#ff007f';
            ctx.font = '16px "Courier New", monospace';
            ctx.shadowColor = '#ff007f';
            ctx.shadowBlur = 10;
            ctx.fillText('RETRO VECTOR ARCADE CAB', canvas.width / 2, 260);

            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 18px "Courier New", monospace';
            ctx.shadowBlur = 0;
            ctx.fillText('PRESS SPACE OR CLICK TO START', canvas.width / 2, 340);

            ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
            ctx.font = '13px "Courier New", monospace';
            ctx.fillText('STEER: ARROWS / WASD   |   FIRE: SPACE / Z', canvas.width / 2, 400);
        } else if (gameState === 'GAMEOVER') {
            ctx.fillStyle = 'rgba(5, 6, 10, 0.85)';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            ctx.fillStyle = '#ff2256';
            ctx.font = 'bold 36px "Courier New", monospace';
            ctx.textAlign = 'center';
            ctx.shadowColor = '#ff2256';
            ctx.shadowBlur = 15;
            ctx.fillText('GAME OVER', canvas.width / 2, 220);

            ctx.fillStyle = '#00f2fe';
            ctx.font = '20px "Courier New", monospace';
            ctx.shadowColor = '#00f2fe';
            ctx.shadowBlur = 8;
            ctx.fillText(`FINAL SCORE: ${score}`, canvas.width / 2, 270);

            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 16px "Courier New", monospace';
            ctx.shadowBlur = 0;
            ctx.fillText('PRESS SPACE TO PLAY AGAIN', canvas.width / 2, 340);
        } else if (isPaused) {
            ctx.fillStyle = 'rgba(5, 6, 10, 0.7)';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            ctx.fillStyle = '#ffd200';
            ctx.font = 'bold 32px "Courier New", monospace';
            ctx.textAlign = 'center';
            ctx.shadowColor = '#ffd200';
            ctx.shadowBlur = 12;
            ctx.fillText('PAUSED', canvas.width / 2, 300);
        }
    }

    // Canvas click to start
    canvas.addEventListener('click', () => {
        initAudio();
        if (gameState === 'START' || gameState === 'GAMEOVER') {
            resetGame();
        }
    });

    window.addEventListener('keydown', e => {
        if (e.code === 'Space') {
            if (gameState === 'START' || gameState === 'GAMEOVER') {
                resetGame();
            }
        }
    });

    // Game Loop
    function loop() {
        update();
        render();
        requestAnimationFrame(loop);
    }

    spawnAsteroids(6);
    loop();
})();
