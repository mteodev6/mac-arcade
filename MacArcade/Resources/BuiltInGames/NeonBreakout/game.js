// Neon Breakout - Synthwave Brick Breaker
// Pure HTML5 Canvas & WebAudio Synthesizer

(function() {
    const canvas = document.getElementById('gameCanvas');
    const ctx = canvas.getContext('2d');

    // Retro Synthwave Sound Synth
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
            if (type === 'bounce') {
                const osc = audioCtx.createOscillator();
                const gain = audioCtx.createGain();
                osc.type = 'sine';
                osc.frequency.setValueAtTime(440, now);
                osc.frequency.exponentialRampToValueAtTime(220, now + 0.08);
                gain.gain.setValueAtTime(0.2, now);
                gain.gain.exponentialRampToValueAtTime(0.01, now + 0.08);
                osc.connect(gain);
                gain.connect(audioCtx.destination);
                osc.start(now);
                osc.stop(now + 0.08);
            } else if (type === 'brick') {
                const osc = audioCtx.createOscillator();
                const gain = audioCtx.createGain();
                osc.type = 'triangle';
                osc.frequency.setValueAtTime(587.33, now);
                osc.frequency.exponentialRampToValueAtTime(880, now + 0.12);
                gain.gain.setValueAtTime(0.25, now);
                gain.gain.exponentialRampToValueAtTime(0.01, now + 0.12);
                osc.connect(gain);
                gain.connect(audioCtx.destination);
                osc.start(now);
                osc.stop(now + 0.12);
            } else if (type === 'powerup') {
                [523.25, 659.25, 783.99, 1046.50].forEach((freq, i) => {
                    const osc = audioCtx.createOscillator();
                    const gain = audioCtx.createGain();
                    osc.type = 'sine';
                    osc.frequency.setValueAtTime(freq, now + i * 0.05);
                    gain.gain.setValueAtTime(0.15, now + i * 0.05);
                    gain.gain.exponentialRampToValueAtTime(0.01, now + i * 0.05 + 0.08);
                    osc.connect(gain);
                    gain.connect(audioCtx.destination);
                    osc.start(now + i * 0.05);
                    osc.stop(now + i * 0.05 + 0.08);
                });
            } else if (type === 'lost') {
                const osc = audioCtx.createOscillator();
                const gain = audioCtx.createGain();
                osc.type = 'sawtooth';
                osc.frequency.setValueAtTime(220, now);
                osc.frequency.exponentialRampToValueAtTime(80, now + 0.35);
                gain.gain.setValueAtTime(0.3, now);
                gain.gain.exponentialRampToValueAtTime(0.01, now + 0.35);
                osc.connect(gain);
                gain.connect(audioCtx.destination);
                osc.start(now);
                osc.stop(now + 0.35);
            }
        } catch (e) {
            console.error(e);
        }
    }

    // State
    let score = 0;
    let highScore = parseInt(localStorage.getItem('neon_breakout_high') || '0', 10);
    let lives = 3;
    let level = 1;
    let gameState = 'START'; // START, PLAYING, GAMEOVER, VICTORY, PAUSED
    let isPaused = false;
    let screenShake = 0;

    // Paddle
    const paddle = {
        width: 110,
        height: 14,
        x: canvas.width / 2 - 55,
        y: canvas.height - 45,
        speed: 8,
        color: '#00f2fe'
    };

    // Balls array
    let balls = [];

    function addBall(x, y, vx, vy) {
        balls.push({
            x, y,
            radius: 6,
            vx, vy,
            speed: 6.5,
            trail: []
        });
    }

    function resetBalls() {
        balls = [];
        addBall(paddle.x + paddle.width / 2, paddle.y - 10, 0, 0);
    }

    // Bricks
    let bricks = [];
    const brickConfig = {
        rows: 6,
        cols: 10,
        width: 68,
        height: 22,
        padding: 8,
        offsetTop: 65,
        offsetLeft: 20
    };

    const brickColors = [
        '#ff007f', // Neon Magenta
        '#ff5500', // Neon Orange
        '#ffd200', // Neon Yellow
        '#39ff14', // Neon Green
        '#00f2fe', // Neon Cyan
        '#b026ff'  // Neon Purple
    ];

    function createBricks() {
        bricks = [];
        for (let c = 0; c < brickConfig.cols; c++) {
            for (let r = 0; r < brickConfig.rows; r++) {
                const brickX = c * (brickConfig.width + brickConfig.padding) + brickConfig.offsetLeft;
                const brickY = r * (brickConfig.height + brickConfig.padding) + brickConfig.offsetTop;
                const color = brickColors[r % brickColors.length];
                const hits = r === 0 ? 2 : 1;
                bricks.push({
                    x: brickX,
                    y: brickY,
                    width: brickConfig.width,
                    height: brickConfig.height,
                    color,
                    hits,
                    maxHits: hits,
                    status: 1
                });
            }
        }
    }

    // Particles & Powerups
    let particles = [];
    let powerups = [];

    function createSparks(x, y, color, count = 12) {
        for (let i = 0; i < count; i++) {
            const angle = Math.random() * Math.PI * 2;
            const speed = Math.random() * 4 + 1;
            particles.push({
                x, y,
                vx: Math.cos(angle) * speed,
                vy: Math.sin(angle) * speed,
                life: 25 + Math.random() * 15,
                maxLife: 40,
                color
            });
        }
    }

    // Controls
    const keys = {};
    window.addEventListener('keydown', e => {
        initAudio();
        keys[e.code] = true;
        if (e.code === 'KeyP') isPaused = !isPaused;
        if (e.code === 'Space') {
            if (gameState === 'START' || gameState === 'GAMEOVER' || gameState === 'VICTORY') {
                startGame();
            } else if (balls.length > 0 && balls[0].vx === 0 && balls[0].vy === 0) {
                // Launch ball
                const angle = -Math.PI / 3 + (Math.random() * Math.PI / 6);
                balls[0].vx = Math.sin(angle) * balls[0].speed;
                balls[0].vy = -Math.cos(angle) * balls[0].speed;
            }
        }
        if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) {
            e.preventDefault();
        }
    });

    window.addEventListener('keyup', e => {
        keys[e.code] = false;
    });

    canvas.addEventListener('mousemove', e => {
        const rect = canvas.getBoundingClientRect();
        const root = document.documentElement;
        const mouseX = e.clientX - rect.left - (paddle.width / 2);
        paddle.x = Math.max(10, Math.min(canvas.width - paddle.width - 10, mouseX));

        // If ball on paddle, move it along
        if (balls.length > 0 && balls[0].vx === 0 && balls[0].vy === 0) {
            balls[0].x = paddle.x + paddle.width / 2;
        }
    });

    canvas.addEventListener('click', () => {
        initAudio();
        if (gameState === 'START' || gameState === 'GAMEOVER' || gameState === 'VICTORY') {
            startGame();
        } else if (balls.length > 0 && balls[0].vx === 0 && balls[0].vy === 0) {
            balls[0].vx = (Math.random() - 0.5) * 4;
            balls[0].vy = -balls[0].speed;
        }
    });

    // Native Bridge
    window.arcadePause = () => { isPaused = true; };
    window.arcadeResume = () => { isPaused = false; };
    window.arcadeRestart = () => { startGame(); };

    function startGame() {
        score = 0;
        lives = 3;
        level = 1;
        paddle.width = 110;
        createBricks();
        resetBalls();
        particles = [];
        powerups = [];
        gameState = 'PLAYING';
        isPaused = false;
    }

    // Update
    function update() {
        if (gameState !== 'PLAYING' || isPaused) return;

        // Screen Shake decay
        if (screenShake > 0) screenShake *= 0.85;
        if (screenShake < 0.2) screenShake = 0;

        // Paddle Keyboard Movement
        if (keys['ArrowLeft'] || keys['KeyA']) {
            paddle.x = Math.max(10, paddle.x - paddle.speed);
            if (balls.length > 0 && balls[0].vx === 0 && balls[0].vy === 0) {
                balls[0].x = paddle.x + paddle.width / 2;
            }
        }
        if (keys['ArrowRight'] || keys['KeyD']) {
            paddle.x = Math.min(canvas.width - paddle.width - 10, paddle.x + paddle.speed);
            if (balls.length > 0 && balls[0].vx === 0 && balls[0].vy === 0) {
                balls[0].x = paddle.x + paddle.width / 2;
            }
        }

        // Balls Update
        for (let i = balls.length - 1; i >= 0; i--) {
            const b = balls[i];

            // Ball still docked on paddle
            if (b.vx === 0 && b.vy === 0) continue;

            // Trail
            b.trail.push({ x: b.x, y: b.y });
            if (b.trail.length > 8) b.trail.shift();

            b.x += b.vx;
            b.y += b.vy;

            // Wall Collisions
            if (b.x + b.radius > canvas.width) {
                b.x = canvas.width - b.radius;
                b.vx = -Math.abs(b.vx);
                playSound('bounce');
            } else if (b.x - b.radius < 0) {
                b.x = b.radius;
                b.vx = Math.abs(b.vx);
                playSound('bounce');
            }

            if (b.y - b.radius < 0) {
                b.y = b.radius;
                b.vy = Math.abs(b.vy);
                playSound('bounce');
            }

            // Paddle Collision
            if (b.y + b.radius >= paddle.y && b.y - b.radius <= paddle.y + paddle.height &&
                b.x >= paddle.x && b.x <= paddle.x + paddle.width && b.vy > 0) {
                
                playSound('bounce');
                createSparks(b.x, paddle.y, paddle.color, 8);

                // Angle adjustment based on hit point on paddle
                const hitPoint = (b.x - (paddle.x + paddle.width / 2)) / (paddle.width / 2);
                const angle = hitPoint * (Math.PI / 3); // Max 60 deg angle
                const currentSpeed = Math.hypot(b.vx, b.vy);
                b.vx = currentSpeed * Math.sin(angle);
                b.vy = -currentSpeed * Math.cos(angle);
            }

            // Brick Collisions
            let activeBricks = 0;
            bricks.forEach(br => {
                if (br.status <= 0) return;
                activeBricks++;

                if (b.x + b.radius > br.x && b.x - b.radius < br.x + br.width &&
                    b.y + b.radius > br.y && b.y - br.radius < br.y + br.height) {
                    
                    br.hits--;
                    if (br.hits <= 0) {
                        br.status = 0;
                        score += 100;
                        createSparks(br.x + br.width / 2, br.y + br.height / 2, br.color, 16);
                        screenShake = 4;
                        playSound('brick');

                        // Powerup Drop Chance
                        if (Math.random() < 0.2) {
                            const types = ['MULTIBALL', 'WIDE', 'SLOW'];
                            powerups.push({
                                x: br.x + br.width / 2,
                                y: br.y + br.height / 2,
                                type: types[Math.floor(Math.random() * types.length)],
                                vy: 2.5
                            });
                        }
                    } else {
                        score += 50;
                        playSound('bounce');
                    }

                    // Rebound ball
                    b.vy = -b.vy;
                }
            });

            // Level Clear Check
            if (activeBricks === 0) {
                gameState = 'VICTORY';
                playSound('powerup');
                if (score > highScore) {
                    highScore = score;
                    localStorage.setItem('neon_breakout_high', highScore.toString());
                }
            }

            // Ball Out of Bounds Bottom
            if (b.y - b.radius > canvas.height) {
                balls.splice(i, 1);
            }
        }

        // If all balls lost
        if (balls.length === 0) {
            playSound('lost');
            lives--;
            if (lives <= 0) {
                gameState = 'GAMEOVER';
                if (score > highScore) {
                    highScore = score;
                    localStorage.setItem('neon_breakout_high', highScore.toString());
                }
            } else {
                resetBalls();
            }
        }

        // Powerups
        for (let i = powerups.length - 1; i >= 0; i--) {
            const p = powerups[i];
            p.y += p.vy;

            // Catch powerup with paddle
            if (p.y >= paddle.y && p.y <= paddle.y + paddle.height &&
                p.x >= paddle.x && p.x <= paddle.x + paddle.width) {
                
                playSound('powerup');
                createSparks(p.x, paddle.y, '#ffd200', 14);

                if (p.type === 'MULTIBALL') {
                    if (balls.length > 0) {
                        const baseBall = balls[0];
                        addBall(baseBall.x, baseBall.y, baseBall.vx + 2, baseBall.vy);
                        addBall(baseBall.x, baseBall.y, baseBall.vx - 2, baseBall.vy);
                    }
                } else if (p.type === 'WIDE') {
                    paddle.width = Math.min(220, paddle.width + 40);
                    setTimeout(() => { paddle.width = 110; }, 8000);
                } else if (p.type === 'SLOW') {
                    balls.forEach(b => { b.vx *= 0.7; b.vy *= 0.7; });
                    setTimeout(() => {
                        balls.forEach(b => {
                            const cur = Math.hypot(b.vx, b.vy);
                            if (cur > 0) {
                                b.vx = (b.vx / cur) * 6.5;
                                b.vy = (b.vy / cur) * 6.5;
                            }
                        });
                    }, 6000);
                }

                powerups.splice(i, 1);
                continue;
            }

            if (p.y > canvas.height) {
                powerups.splice(i, 1);
            }
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

    // Render
    function render() {
        ctx.save();
        if (screenShake > 0) {
            ctx.translate((Math.random() - 0.5) * screenShake, (Math.random() - 0.5) * screenShake);
        }

        ctx.fillStyle = '#0d081f';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        // Synthwave Perspective Grid at bottom
        ctx.strokeStyle = 'rgba(255, 0, 127, 0.15)';
        ctx.lineWidth = 1;
        const horizon = canvas.height * 0.75;
        for (let x = -200; x < canvas.width + 200; x += 60) {
            ctx.beginPath();
            ctx.moveTo(canvas.width / 2, horizon);
            ctx.lineTo(x, canvas.height);
            ctx.stroke();
        }
        for (let y = horizon; y < canvas.height; y += 15) {
            ctx.beginPath();
            ctx.moveTo(0, y);
            ctx.lineTo(canvas.width, y);
            ctx.stroke();
        }

        // Bricks
        bricks.forEach(br => {
            if (br.status <= 0) return;
            ctx.fillStyle = br.color;
            ctx.shadowColor = br.color;
            ctx.shadowBlur = br.hits > 1 ? 16 : 8;
            ctx.fillRect(br.x, br.y, br.width, br.height);

            // Inner bevel
            ctx.strokeStyle = 'rgba(255, 255, 255, 0.4)';
            ctx.lineWidth = 1;
            ctx.strokeRect(br.x + 1, br.y + 1, br.width - 2, br.height - 2);
        });

        // Paddle
        ctx.fillStyle = paddle.color;
        ctx.shadowColor = paddle.color;
        ctx.shadowBlur = 18;
        ctx.beginPath();
        ctx.roundRect(paddle.x, paddle.y, paddle.width, paddle.height, [6, 6, 2, 2]);
        ctx.fill();

        // Paddle accent center
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(paddle.x + paddle.width / 2 - 8, paddle.y + 3, 16, paddle.height - 6);

        // Balls and trails
        balls.forEach(b => {
            // Trail
            b.trail.forEach((t, idx) => {
                ctx.fillStyle = `rgba(255, 0, 127, ${idx / 12})`;
                ctx.beginPath();
                ctx.arc(t.x, t.y, b.radius * (idx / b.trail.length), 0, Math.PI * 2);
                ctx.fill();
            });

            ctx.fillStyle = '#ffffff';
            ctx.shadowColor = '#ff007f';
            ctx.shadowBlur = 14;
            ctx.beginPath();
            ctx.arc(b.x, b.y, b.radius, 0, Math.PI * 2);
            ctx.fill();
        });

        // Powerups
        powerups.forEach(p => {
            ctx.fillStyle = '#ffd200';
            ctx.shadowColor = '#ffd200';
            ctx.shadowBlur = 12;
            ctx.beginPath();
            ctx.arc(p.x, p.y, 9, 0, Math.PI * 2);
            ctx.fill();

            ctx.fillStyle = '#000000';
            ctx.font = 'bold 9px sans-serif';
            ctx.textAlign = 'center';
            const label = p.type === 'MULTIBALL' ? '3x' : p.type === 'WIDE' ? '<>' : 'S';
            ctx.fillText(label, p.x, p.y + 3);
        });

        // Particles
        particles.forEach(pt => {
            ctx.fillStyle = pt.color;
            ctx.shadowColor = pt.color;
            ctx.shadowBlur = 6;
            ctx.globalAlpha = pt.life / pt.maxLife;
            ctx.fillRect(pt.x, pt.y, 3, 3);
        });
        ctx.globalAlpha = 1.0;

        // Top HUD
        ctx.shadowBlur = 0;
        ctx.fillStyle = '#ff007f';
        ctx.font = 'bold 15px sans-serif';
        ctx.textAlign = 'left';
        ctx.fillText(`SCORE: ${score}`, 20, 30);
        ctx.textAlign = 'center';
        ctx.fillText(`LIVES: ${'❤️ '.repeat(lives)}`, canvas.width / 2, 30);
        ctx.textAlign = 'right';
        ctx.fillText(`HIGH: ${highScore}`, canvas.width - 20, 30);

        // Overlays
        if (gameState === 'START') {
            ctx.fillStyle = 'rgba(13, 8, 31, 0.85)';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            ctx.fillStyle = '#ff007f';
            ctx.font = '900 40px sans-serif';
            ctx.textAlign = 'center';
            ctx.shadowColor = '#ff007f';
            ctx.shadowBlur = 20;
            ctx.fillText('NEON BREAKOUT', canvas.width / 2, 220);

            ctx.fillStyle = '#00f2fe';
            ctx.font = 'bold 16px sans-serif';
            ctx.shadowColor = '#00f2fe';
            ctx.shadowBlur = 10;
            ctx.fillText('SYNTHWAVE ARCADE CAB', canvas.width / 2, 260);

            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 18px sans-serif';
            ctx.shadowBlur = 0;
            ctx.fillText('CLICK OR PRESS SPACE TO LAUNCH', canvas.width / 2, 340);
        } else if (gameState === 'GAMEOVER') {
            ctx.fillStyle = 'rgba(13, 8, 31, 0.85)';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            ctx.fillStyle = '#ff2256';
            ctx.font = '900 38px sans-serif';
            ctx.textAlign = 'center';
            ctx.shadowColor = '#ff2256';
            ctx.shadowBlur = 20;
            ctx.fillText('GAME OVER', canvas.width / 2, 220);

            ctx.fillStyle = '#00f2fe';
            ctx.font = 'bold 20px sans-serif';
            ctx.fillText(`SCORE: ${score}`, canvas.width / 2, 270);

            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 16px sans-serif';
            ctx.shadowBlur = 0;
            ctx.fillText('CLICK OR PRESS SPACE TO TRY AGAIN', canvas.width / 2, 340);
        } else if (gameState === 'VICTORY') {
            ctx.fillStyle = 'rgba(13, 8, 31, 0.85)';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            ctx.fillStyle = '#39ff14';
            ctx.font = '900 38px sans-serif';
            ctx.textAlign = 'center';
            ctx.shadowColor = '#39ff14';
            ctx.shadowBlur = 20;
            ctx.fillText('VICTORY! STAGE CLEAR', canvas.width / 2, 220);

            ctx.fillStyle = '#00f2fe';
            ctx.font = 'bold 20px sans-serif';
            ctx.fillText(`FINAL SCORE: ${score}`, canvas.width / 2, 270);

            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 16px sans-serif';
            ctx.shadowBlur = 0;
            ctx.fillText('CLICK OR PRESS SPACE TO PLAY AGAIN', canvas.width / 2, 340);
        } else if (isPaused) {
            ctx.fillStyle = 'rgba(13, 8, 31, 0.7)';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            ctx.fillStyle = '#ffd200';
            ctx.font = 'bold 32px sans-serif';
            ctx.textAlign = 'center';
            ctx.shadowColor = '#ffd200';
            ctx.shadowBlur = 12;
            ctx.fillText('PAUSED', canvas.width / 2, 300);
        }

        ctx.restore();
    }

    // Loop
    function loop() {
        update();
        render();
        requestAnimationFrame(loop);
    }

    createBricks();
    resetBalls();
    loop();
})();
