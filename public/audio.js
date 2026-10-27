/**
 * Castle Attack - Web Audio API Synthesizer (Enhanced High-Polish Edition)
 * 100% procedural sound generation - layered multi-oscillator synthesis for AAA mobile punch.
 */

class SoundEngine {
    constructor() {
        this.ctx = null;
        this.isMuted = false;
        this.unlocked = false;
    }

    init() {
        if (!this.ctx) {
            const AudioCtx = window.AudioContext || window.webkitAudioContext;
            this.ctx = new AudioCtx();
        }
        if (this.ctx && this.ctx.state === 'suspended') {
            this.ctx.resume();
        }
        this.unlocked = true;
    }

    ensureContext() {
        if (!this.ctx) this.init();
        if (this.ctx && this.ctx.state === 'suspended') {
            this.ctx.resume();
        }
    }

    // Native mobile haptic feedback wrapper
    vibrate(pattern) {
        if (typeof navigator !== 'undefined' && navigator.vibrate) {
            try {
                navigator.vibrate(pattern);
            } catch (e) {
                // Ignore if not permitted
            }
        }
    }

    // Whoosh: Layered bandpass noise + low resonance body
    playWhoosh(duration = 0.28) {
        if (this.isMuted) return;
        this.ensureContext();
        if (!this.ctx) return;

        const ctx = this.ctx;
        const now = ctx.currentTime;

        const bufferSize = Math.floor(ctx.sampleRate * duration);
        const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
        const data = buffer.getChannelData(0);
        for (let i = 0; i < bufferSize; i++) {
            data[i] = Math.random() * 2 - 1;
        }

        const noise = ctx.createBufferSource();
        noise.buffer = buffer;

        const filter = ctx.createBiquadFilter();
        filter.type = 'bandpass';
        filter.Q.setValueAtTime(3.5, now);
        filter.frequency.setValueAtTime(250, now);
        filter.frequency.exponentialRampToValueAtTime(2200, now + duration * 0.55);
        filter.frequency.exponentialRampToValueAtTime(350, now + duration);

        const gain = ctx.createGain();
        gain.gain.setValueAtTime(0.01, now);
        gain.gain.linearRampToValueAtTime(0.4, now + duration * 0.3);
        gain.gain.exponentialRampToValueAtTime(0.01, now + duration);

        noise.connect(filter);
        filter.connect(gain);
        gain.connect(ctx.destination);

        noise.start(now);
        noise.stop(now + duration);
    }

    // Bow string twang / projectile release
    playBowRelease() {
        if (this.isMuted) return;
        this.ensureContext();
        if (!this.ctx) return;

        const ctx = this.ctx;
        const now = ctx.currentTime;

        const osc = ctx.createOscillator();
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(360, now);
        osc.frequency.exponentialRampToValueAtTime(110, now + 0.12);

        const filter = ctx.createBiquadFilter();
        filter.type = 'lowpass';
        filter.frequency.setValueAtTime(1600, now);
        filter.frequency.exponentialRampToValueAtTime(200, now + 0.12);

        const gain = ctx.createGain();
        gain.gain.setValueAtTime(0.3, now);
        gain.gain.exponentialRampToValueAtTime(0.01, now + 0.12);

        osc.connect(filter);
        filter.connect(gain);
        gain.connect(ctx.destination);

        osc.start(now);
        osc.stop(now + 0.12);
    }

    // Impact: Deep sub-bass punch + crunchy mid thud
    playImpact(strength = 1.0) {
        if (this.isMuted) return;
        this.ensureContext();
        if (!this.ctx) return;

        this.vibrate([45]);
        const ctx = this.ctx;
        const now = ctx.currentTime;
        const duration = 0.32;

        // Sub bass layer (60Hz -> 25Hz)
        const sub = ctx.createOscillator();
        sub.type = 'sine';
        sub.frequency.setValueAtTime(160, now);
        sub.frequency.exponentialRampToValueAtTime(30, now + duration);

        const subGain = ctx.createGain();
        subGain.gain.setValueAtTime(0.7 * strength, now);
        subGain.gain.exponentialRampToValueAtTime(0.01, now + duration);

        sub.connect(subGain);
        subGain.connect(ctx.destination);
        sub.start(now);
        sub.stop(now + duration);

        // Crunch transient
        const bufferSize = Math.floor(ctx.sampleRate * 0.08);
        const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
        const data = buffer.getChannelData(0);
        for (let i = 0; i < bufferSize; i++) data[i] = (Math.random() * 2 - 1) * 0.5;

        const noise = ctx.createBufferSource();
        noise.buffer = buffer;

        const nFilter = ctx.createBiquadFilter();
        nFilter.type = 'lowpass';
        nFilter.frequency.setValueAtTime(900, now);

        const nGain = ctx.createGain();
        nGain.gain.setValueAtTime(0.5 * strength, now);
        nGain.gain.exponentialRampToValueAtTime(0.01, now + 0.08);

        noise.connect(nFilter);
        nFilter.connect(nGain);
        nGain.connect(ctx.destination);

        noise.start(now);
        noise.stop(now + 0.08);
    }

    // Card play liquid pop / chime
    playCardPlay() {
        if (this.isMuted) return;
        this.ensureContext();
        if (!this.ctx) return;

        this.vibrate([20]);
        const ctx = this.ctx;
        const now = ctx.currentTime;

        const osc = ctx.createOscillator();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(320, now);
        osc.frequency.exponentialRampToValueAtTime(680, now + 0.09);

        const gain = ctx.createGain();
        gain.gain.setValueAtTime(0.25, now);
        gain.gain.exponentialRampToValueAtTime(0.01, now + 0.12);

        osc.connect(gain);
        gain.connect(ctx.destination);

        osc.start(now);
        osc.stop(now + 0.12);
    }

    // Shield: Glowing harmonic bell chime
    playShield() {
        if (this.isMuted) return;
        this.ensureContext();
        if (!this.ctx) return;

        this.vibrate([25, 40]);
        const ctx = this.ctx;
        const now = ctx.currentTime;
        const duration = 0.6;

        [440, 880, 1320].forEach((freq, idx) => {
            const osc = ctx.createOscillator();
            osc.type = idx === 1 ? 'triangle' : 'sine';
            osc.frequency.setValueAtTime(freq, now);
            osc.frequency.exponentialRampToValueAtTime(freq * 1.5, now + 0.35);

            const gain = ctx.createGain();
            const start = now + idx * 0.03;
            gain.gain.setValueAtTime(0.01, start);
            gain.gain.linearRampToValueAtTime(0.25 / (idx + 1), start + 0.05);
            gain.gain.exponentialRampToValueAtTime(0.005, start + duration);

            osc.connect(gain);
            gain.connect(ctx.destination);

            osc.start(start);
            osc.stop(start + duration);
        });
    }

    // Repair: Arpeggiated crystal triad (C5 - 523Hz, E5 - 659Hz, G5 - 784Hz, C6 - 1046Hz)
    playRepair() {
        if (this.isMuted) return;
        this.ensureContext();
        if (!this.ctx) return;

        this.vibrate([20, 20, 20]);
        const ctx = this.ctx;
        const now = ctx.currentTime;
        const notes = [523.25, 659.25, 783.99, 1046.50];

        notes.forEach((freq, idx) => {
            const osc = ctx.createOscillator();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(freq, now + idx * 0.06);

            const gain = ctx.createGain();
            const start = now + idx * 0.06;
            gain.gain.setValueAtTime(0.01, start);
            gain.gain.linearRampToValueAtTime(0.28, start + 0.02);
            gain.gain.exponentialRampToValueAtTime(0.005, start + 0.4);

            osc.connect(gain);
            gain.connect(ctx.destination);

            osc.start(start);
            osc.stop(start + 0.4);
        });
    }

    // Explosion: Volumetric sub-bass drop + low-frequency blast + lingering crackle
    playExplosion() {
        if (this.isMuted) return;
        this.ensureContext();
        if (!this.ctx) return;

        this.vibrate([120, 60, 180]);
        const ctx = this.ctx;
        const now = ctx.currentTime;
        const duration = 0.75;

        // Sub bass drop
        const sub = ctx.createOscillator();
        sub.type = 'sine';
        sub.frequency.setValueAtTime(110, now);
        sub.frequency.exponentialRampToValueAtTime(20, now + duration);

        const subGain = ctx.createGain();
        subGain.gain.setValueAtTime(0.9, now);
        subGain.gain.exponentialRampToValueAtTime(0.01, now + duration);

        sub.connect(subGain);
        subGain.connect(ctx.destination);
        sub.start(now);
        sub.stop(now + duration);

        // Heavy Noise blast
        const bufferSize = Math.floor(ctx.sampleRate * duration);
        const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
        const data = buffer.getChannelData(0);
        for (let i = 0; i < bufferSize; i++) data[i] = Math.random() * 2 - 1;

        const noise = ctx.createBufferSource();
        noise.buffer = buffer;

        const filter = ctx.createBiquadFilter();
        filter.type = 'lowpass';
        filter.frequency.setValueAtTime(1100, now);
        filter.frequency.exponentialRampToValueAtTime(80, now + duration);

        const noiseGain = ctx.createGain();
        noiseGain.gain.setValueAtTime(0.85, now);
        noiseGain.gain.exponentialRampToValueAtTime(0.01, now + duration);

        noise.connect(filter);
        filter.connect(noiseGain);
        noiseGain.connect(ctx.destination);

        noise.start(now);
        noise.stop(now + duration);
    }

    // Slingshot pull stretch tick
    playSlingshotTick(tension = 0.5) {
        if (this.isMuted) return;
        this.ensureContext();
        if (!this.ctx) return;

        const ctx = this.ctx;
        const now = ctx.currentTime;
        const osc = ctx.createOscillator();
        osc.type = 'triangle';
        osc.frequency.setValueAtTime(240 + tension * 420, now);

        const gain = ctx.createGain();
        gain.gain.setValueAtTime(0.09, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.035);

        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(now);
        osc.stop(now + 0.035);
    }

    // Victory Fanfare: Brass major triad flourish
    playVictory() {
        if (this.isMuted) return;
        this.ensureContext();
        if (!this.ctx) return;

        this.vibrate([100, 50, 100, 50, 320]);
        const ctx = this.ctx;
        const now = ctx.currentTime;
        const notes = [
            { f: 523.25, t: 0.0, d: 0.16 }, // C5
            { f: 659.25, t: 0.16, d: 0.16 }, // E5
            { f: 783.99, t: 0.32, d: 0.20 }, // G5
            { f: 1046.50, t: 0.52, d: 0.65 } // C6
        ];

        notes.forEach(({ f, t, d }) => {
            const osc = ctx.createOscillator();
            osc.type = 'sawtooth';
            osc.frequency.setValueAtTime(f, now + t);

            const filter = ctx.createBiquadFilter();
            filter.type = 'lowpass';
            filter.frequency.setValueAtTime(2400, now + t);

            const gain = ctx.createGain();
            const start = now + t;
            gain.gain.setValueAtTime(0.01, start);
            gain.gain.linearRampToValueAtTime(0.35, start + 0.03);
            gain.gain.exponentialRampToValueAtTime(0.01, start + d);

            osc.connect(filter);
            filter.connect(gain);
            gain.connect(ctx.destination);

            osc.start(start);
            osc.stop(start + d);
        });
    }

    // Defeat Fanfare: Somber descending minor chord
    playDefeat() {
        if (this.isMuted) return;
        this.ensureContext();
        if (!this.ctx) return;

        this.vibrate([200, 100, 200]);
        const ctx = this.ctx;
        const now = ctx.currentTime;
        const notes = [
            { f: 440.0, t: 0.0, d: 0.28 },
            { f: 415.3, t: 0.28, d: 0.32 },
            { f: 392.0, t: 0.60, d: 0.65 }
        ];

        notes.forEach(({ f, t, d }) => {
            const osc = ctx.createOscillator();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(f, now + t);

            const gain = ctx.createGain();
            const start = now + t;
            gain.gain.setValueAtTime(0.01, start);
            gain.gain.linearRampToValueAtTime(0.3, start + 0.03);
            gain.gain.exponentialRampToValueAtTime(0.01, start + d);

            osc.connect(gain);
            gain.connect(ctx.destination);

            osc.start(start);
            osc.stop(start + d);
        });
    }
}

// Global sound instance
window.sound = new SoundEngine();
