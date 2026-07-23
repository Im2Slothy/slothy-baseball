const ui = document.querySelector('#baseball-ui');
const strikeZone = document.querySelector('#strike-zone');
const pciElement = document.querySelector('#pci');
const pitchBall = document.querySelector('#pitch-ball');
const locationLabel = document.querySelector('#location-label');
const handednessLabel = document.querySelector('#handedness-label');
const pitchLabel = document.querySelector('#pitch-label');
const debugOverlay = document.querySelector('#debug-overlay');
const resultPanel = document.querySelector('#result-panel');
const resultHeadline = document.querySelector('#result-headline');
const resultName = document.querySelector('#result-name');
const resultStats = document.querySelector('#result-stats');
const ballCameraState = document.querySelector('#ball-camera-state');

const state = {
    visible: false,
    targetX: 0,
    targetY: 0,
    currentX: 0,
    currentY: 0,
    maximumX: 1,
    maximumY: 1,
    sensitivity: 1,
    smoothing: 0.18,
    radius: 0.18,
    lastFrameAt: performance.now(),
    lastSentAt: 0,
    lastSentX: 0,
    lastSentY: 0,
    soundsEnabled: true,
    soundVolume: 0.48,
    audioContext: null,
    battingView: 'ready',
    pitch: {
        active: false,
        x: 0,
        y: 0,
        size: 7
    }
};

function clamp(value, minimum, maximum) {
    return Math.min(Math.max(value, minimum), maximum);
}

function postNui(endpoint, data = {}) {
    if (typeof GetParentResourceName !== 'function') {
        return Promise.resolve();
    }

    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => undefined);
}

function setBattingView(view) {
    const nextView = ['ready', 'pitch', 'follow'].includes(view) ? view : 'ready';
    state.battingView = nextView;
    ui.classList.toggle('zone-faded', nextView !== 'ready');
    ui.classList.toggle('pci-faded', nextView === 'follow');
}

function resetPCI(x = 0, y = 0) {
    state.targetX = clamp(Number(x) || 0, -state.maximumX, state.maximumX);
    state.targetY = clamp(Number(y) || 0, -state.maximumY, state.maximumY);
    state.currentX = state.targetX;
    state.currentY = state.targetY;
    state.lastSentX = state.currentX;
    state.lastSentY = state.currentY;
}

function configure(data) {
    const zone = data.strikeZone || {};
    const pci = data.pci || {};
    const sounds = data.sounds || {};

    document.documentElement.style.setProperty('--zone-width', `${Number(zone.widthVw) || 21}vw`);
    document.documentElement.style.setProperty('--zone-height', `${Number(zone.heightVh) || 38}vh`);
    document.documentElement.style.setProperty('--zone-center-x', `${Number(zone.centerXPercent) || 50}%`);
    document.documentElement.style.setProperty('--zone-center-y', `${Number(zone.centerYPercent) || 48}%`);

    strikeZone.classList.toggle('show-grid', zone.showGrid === true);
    state.maximumX = Math.max(0.05, Number(pci.maximumX) || 1);
    state.maximumY = Math.max(0.05, Number(pci.maximumY) || 1);
    state.sensitivity = Math.max(0.05, Number(pci.sensitivity) || 1);
    state.smoothing = clamp(Number(pci.smoothing) || 0.18, 0.01, 1);
    state.radius = Math.max(0.04, Number(pci.defaultRadius) || 0.18);

    locationLabel.textContent = data.locationLabel || 'Batting Practice';
    const hand = String(data.handedness || 'right').toLowerCase();
    handednessLabel.textContent = `${hand === 'left' ? 'Left' : 'Right'}-handed batter`;
    debugOverlay.classList.toggle('visible', data.debugEnabled === true);
    state.soundsEnabled = sounds.enabled !== false;
    const configuredVolume = Number(sounds.volume);
    state.soundVolume = clamp(Number.isFinite(configuredVolume) ? configuredVolume : 0.48, 0, 1);
    ballCameraState.textContent = data.ballCameraEnabled === false ? 'OFF' : 'ON';
    resetPCI();
    setBattingView('ready');
}

function positionPCI() {
    const zoneRect = strikeZone.getBoundingClientRect();
    const diameter = Math.max(44, Math.min(zoneRect.width, zoneRect.height) * state.radius * 2);

    pciElement.style.width = `${diameter}px`;
    pciElement.style.height = `${diameter}px`;
    pciElement.style.left = `${zoneRect.width / 2 + state.currentX * zoneRect.width / 2}px`;
    pciElement.style.top = `${zoneRect.height / 2 - state.currentY * zoneRect.height / 2}px`;
}

function positionPitch() {
    if (!state.pitch.active) {
        return;
    }

    const zoneRect = strikeZone.getBoundingClientRect();
    const left = ((state.pitch.x + 1) / 2) * zoneRect.width;
    const top = ((1 - state.pitch.y) / 2) * zoneRect.height;

    pitchBall.style.left = `${left}px`;
    pitchBall.style.top = `${top}px`;
    pitchBall.style.width = `${state.pitch.size}px`;
    pitchBall.style.height = `${state.pitch.size}px`;
}

function showResult(data) {
    const rows = [
        `Timing: ${data.timing || 'N/A'}`,
        `PCI: ${data.placement || 'N/A'}`
    ];

    if (Number.isFinite(Number(data.contactScore))) {
        rows.push(`Contact: ${Math.round(Number(data.contactScore) * 100)}%`);
    }

    if (Number.isFinite(Number(data.exitVelocity))) {
        rows.push(`Exit velocity: ${Number(data.exitVelocity).toFixed(1)} MPH`);
    }

    if (Number.isFinite(Number(data.launchAngle))) {
        rows.push(`Launch angle: ${Number(data.launchAngle).toFixed(1)}°`);
    }

    if (Number.isFinite(Number(data.distance))) {
        rows.push(`Distance: ${Math.round(Number(data.distance))} FT`);
    }

    resultHeadline.textContent = data.headline || 'SWING RESULT';
    resultName.textContent = data.result || '';
    resultStats.textContent = rows.join('\n');
    resultPanel.classList.add('visible');
}

function updateDebug(data) {
    const number = (value) => (Number(value) || 0).toFixed(3);

    debugOverlay.textContent = [
        `PHASE       ${String(data.phase || 'idle').toUpperCase()}`,
        `PITCH       ${String(data.pitchType || 'none')}`,
        `PROGRESS    ${number(data.progress)}  ideal ${number(data.idealProgress)}`,
        `BALL X/Y    ${number(data.ballX)} / ${number(data.ballY)}`,
        `PCI X/Y     ${number(data.pciX)} / ${number(data.pciY)}`,
        `DISTANCE    ${number(data.distance)}`,
        `SWUNG       ${data.hasSwung === true ? 'YES' : 'NO'}`
    ].join('\n');
}

function getAudioContext() {
    if (state.audioContext) {
        return state.audioContext;
    }

    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext) {
        return null;
    }

    state.audioContext = new AudioContext();
    return state.audioContext;
}

function playSwingSound(contact) {
    if (!state.soundsEnabled) {
        return;
    }

    const context = getAudioContext();
    if (!context) {
        return;
    }

    context.resume();
    const now = context.currentTime;
    const duration = contact ? 0.1 : 0.16;
    const buffer = context.createBuffer(1, context.sampleRate * duration, context.sampleRate);
    const samples = buffer.getChannelData(0);

    for (let index = 0; index < samples.length; index += 1) {
        const fade = 1 - (index / samples.length);
        samples[index] = (Math.random() * 2 - 1) * fade;
    }

    const source = context.createBufferSource();
    const filter = context.createBiquadFilter();
    const gain = context.createGain();
    source.buffer = buffer;
    filter.type = contact ? 'bandpass' : 'lowpass';
    filter.frequency.value = contact ? 1250 : 420;
    filter.Q.value = contact ? 1.8 : 0.7;
    gain.gain.setValueAtTime(state.soundVolume * (contact ? 0.9 : 0.34), now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + duration);
    source.connect(filter);
    filter.connect(gain);
    gain.connect(context.destination);
    source.start(now);

    if (contact) {
        const tone = context.createOscillator();
        const toneGain = context.createGain();
        tone.type = 'triangle';
        tone.frequency.setValueAtTime(185, now);
        tone.frequency.exponentialRampToValueAtTime(72, now + 0.085);
        toneGain.gain.setValueAtTime(state.soundVolume * 0.42, now);
        toneGain.gain.exponentialRampToValueAtTime(0.001, now + 0.09);
        tone.connect(toneGain);
        toneGain.connect(context.destination);
        tone.start(now);
        tone.stop(now + 0.1);
    }
}

function sendPositionIfNeeded(now) {
    const moved = Math.abs(state.currentX - state.lastSentX) > 0.002
        || Math.abs(state.currentY - state.lastSentY) > 0.002;

    if (!moved || now - state.lastSentAt < 32) {
        return;
    }

    state.lastSentAt = now;
    state.lastSentX = state.currentX;
    state.lastSentY = state.currentY;
    postNui('pciMove', { x: state.currentX, y: state.currentY });
}

function render(now) {
    const deltaFrames = Math.max(0.25, Math.min(4, (now - state.lastFrameAt) / 16.667));
    const smoothing = 1 - Math.pow(1 - state.smoothing, deltaFrames);
    state.lastFrameAt = now;

    if (state.visible) {
        state.currentX += (state.targetX - state.currentX) * smoothing;
        state.currentY += (state.targetY - state.currentY) * smoothing;
        positionPCI();
        positionPitch();
        sendPositionIfNeeded(now);
    }

    requestAnimationFrame(render);
}

window.addEventListener('pointermove', (event) => {
    if (!state.visible) {
        return;
    }

    const zoneRect = strikeZone.getBoundingClientRect();
    const relativeX = (event.clientX - (zoneRect.left + zoneRect.width / 2)) / (zoneRect.width / 2);
    const relativeY = ((zoneRect.top + zoneRect.height / 2) - event.clientY) / (zoneRect.height / 2);

    state.targetX = clamp(relativeX * state.sensitivity, -state.maximumX, state.maximumX);
    state.targetY = clamp(relativeY * state.sensitivity, -state.maximumY, state.maximumY);
});

window.addEventListener('pointerdown', (event) => {
    if (!state.visible || event.button !== 0) {
        return;
    }

    event.preventDefault();
    const context = getAudioContext();
    if (context) {
        context.resume();
    }
    postNui('swing', {
        pciX: state.currentX,
        pciY: state.currentY
    });
});

window.addEventListener('keydown', (event) => {
    if (!state.visible) {
        return;
    }

    if (event.code === 'Backspace') {
        event.preventDefault();
        postNui('exit');
    } else if (event.code === 'Space' && !event.repeat) {
        event.preventDefault();
        postNui('requestPitch');
    } else if (event.code === 'KeyC' && !event.repeat) {
        event.preventDefault();
        postNui('toggleBallCamera');
    }
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    switch (data.action) {
        case 'configure':
            configure(data);
            break;
        case 'setVisible':
            state.visible = data.visible === true;
            ui.classList.toggle('visible', state.visible);
            ui.setAttribute('aria-hidden', String(!state.visible));
            state.lastFrameAt = performance.now();
            if (!state.visible) {
                setBattingView('ready');
            }
            break;
        case 'setPCI':
            state.radius = Math.max(0.04, Number(data.radius) || state.radius);
            resetPCI(data.x, data.y);
            break;
        case 'pitchStatus':
            pitchLabel.textContent = data.label || 'Pitcher ready';
            setBattingView('pitch');
            break;
        case 'pitchPrompt':
            pitchLabel.textContent = 'Press Space for pitch';
            setBattingView('ready');
            break;
        case 'swingFeedback': {
            const feedbackClass = data.contact === true ? 'contact' : 'miss';
            const contact = data.contact === true;
            const soundDelayMs = Math.max(0, Number(data.soundDelayMs) || 0);
            if (soundDelayMs > 0) {
                setTimeout(() => {
                    if (state.visible) {
                        playSwingSound(contact);
                    }
                }, soundDelayMs);
            } else {
                playSwingSound(contact);
            }
            pciElement.classList.remove('contact', 'miss');
            requestAnimationFrame(() => pciElement.classList.add(feedbackClass));
            setTimeout(() => pciElement.classList.remove(feedbackClass), 350);
            setBattingView('follow');
            break;
        }
        case 'showResult':
            showResult(data);
            break;
        case 'hideResult':
            resultPanel.classList.remove('visible');
            break;
        case 'updateDebug':
            updateDebug(data);
            break;
        case 'setDebug':
            debugOverlay.classList.toggle('visible', data.visible === true);
            break;
        case 'setBallCamera':
            ballCameraState.textContent = data.enabled === true ? 'ON' : 'OFF';
            break;
        case 'startPitch':
            setBattingView('pitch');
            state.pitch.active = true;
            state.pitch.x = Number(data.x) || 0;
            state.pitch.y = Number(data.y) || 0;
            state.pitch.size = Number(data.size) || 7;
            pitchBall.classList.add('visible');
            pitchLabel.textContent = `${data.label || 'Pitch'}  •  ${Number(data.speedMph) || 0} MPH`;
            break;
        case 'updatePitch':
            state.pitch.x = Number(data.x) || 0;
            state.pitch.y = Number(data.y) || 0;
            state.pitch.size = Number(data.size) || state.pitch.size;
            break;
        case 'endPitch':
            state.pitch.active = false;
            pitchBall.classList.remove('visible');
            pitchLabel.textContent = 'Resetting pitcher';
            setBattingView('follow');
            break;
        case 'resetPitch':
            state.pitch.active = false;
            pitchBall.classList.remove('visible');
            pitchLabel.textContent = 'Press Space for pitch';
            setBattingView('ready');
            break;
        case 'reset':
            resetPCI();
            resultPanel.classList.remove('visible');
            setBattingView('ready');
            break;
        default:
            break;
    }
});

requestAnimationFrame(render);

// Make the page directly previewable in a normal browser without affecting NUI.
if (typeof GetParentResourceName !== 'function') {
    configure({
        locationLabel: 'Grove Street Ballfield',
        handedness: 'right',
        strikeZone: {
            widthVw: 21,
            heightVh: 38,
            centerXPercent: 50,
            centerYPercent: 48,
            showGrid: true
        },
        pci: {
            maximumX: 1,
            maximumY: 1,
            sensitivity: 1,
            smoothing: 0.18,
            defaultRadius: 0.18
        }
    });
    state.visible = true;
    ui.classList.add('visible');
    ui.setAttribute('aria-hidden', 'false');
} else {
    postNui('uiReady');
}
