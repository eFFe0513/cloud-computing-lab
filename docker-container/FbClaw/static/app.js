/* app.js — FbClaw Web Client */

// ── Session management ────────────────────────────────────────────────────────
let sessionId = localStorage.getItem('fbclaw_session') || makeSessionId();

function makeSessionId() {
  const id = 'web-' + Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
  localStorage.setItem('fbclaw_session', id);
  return id;
}

document.getElementById('session-label').textContent = 'Sessione: ' + sessionId.slice(-8);

// Controlla stato del server
fetch('/api/status')
  .then(r => r.json())
  .then(d => {
    document.getElementById('status-dot').style.background = d.status === 'ok' ? '#22c55e' : '#f87171';
  })
  .catch(() => {
    document.getElementById('status-dot').style.background = '#f87171';
  });

// ── Textarea auto-resize + Enter to send ─────────────────────────────────────
const input = document.getElementById('msg-input');

input.addEventListener('input', () => {
  input.style.height = 'auto';
  input.style.height = Math.min(input.scrollHeight, 160) + 'px';
});

input.addEventListener('keydown', e => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    handleSend();
  }
});

// ── Send text message ─────────────────────────────────────────────────────────
async function handleSend() {
  const text = input.value.trim();
  if (!text) return;
  input.value = '';
  input.style.height = 'auto';
  await sendText(text);
}

function quickSend(text) {
  sendText(text);
}

async function sendText(text) {
  removeWelcome();
  addMessage('user', escapeHtml(text));
  const typing = addTyping();
  setInputDisabled(true);

  try {
    const res = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: text, session_id: sessionId }),
    });
    const data = await res.json();
    typing.remove();
    if (res.ok) {
      addMessage('ai', renderMarkdown(data.response ?? ''));
    } else {
      addMessage('ai', `<span style="color:var(--error)">⚠️ Errore: ${escapeHtml(data.detail ?? 'sconosciuto')}</span>`);
    }
  } catch (err) {
    typing.remove();
    addMessage('ai', `<span style="color:var(--error)">⚠️ Connessione fallita: ${escapeHtml(err.message)}</span>`);
  } finally {
    setInputDisabled(false);
    input.focus();
  }
}

// ── Voice recording ───────────────────────────────────────────────────────────
let mediaRecorder = null;
let audioChunks = [];
let isRecording = false;

async function toggleRecord() {
  if (isRecording) stopRecording();
  else await startRecording();
}

async function startRecording() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    // Preferisci audio/webm, fallback a audio/ogg
    const mimeType = MediaRecorder.isTypeSupported('audio/webm') ? 'audio/webm' : 'audio/ogg';
    mediaRecorder = new MediaRecorder(stream, { mimeType });
    audioChunks = [];

    mediaRecorder.ondataavailable = e => {
      if (e.data.size > 0) audioChunks.push(e.data);
    };

    mediaRecorder.onstop = async () => {
      const blob = new Blob(audioChunks, { type: mediaRecorder.mimeType });
      stream.getTracks().forEach(t => t.stop());
      await sendVoice(blob);
    };

    mediaRecorder.start(250); // chunk ogni 250ms
    isRecording = true;

    const btn = document.getElementById('btn-record');
    btn.classList.add('recording');
    btn.textContent = '⏹️';
    btn.title = 'Ferma registrazione';
    document.getElementById('rec-bar').textContent = '● Registrazione in corso… clicca ⏹️ per inviare';
  } catch (err) {
    addMessage('ai', `<span style="color:var(--error)">⚠️ Microfono non disponibile: ${escapeHtml(err.message)}</span>`);
  }
}

function stopRecording() {
  if (mediaRecorder && mediaRecorder.state !== 'inactive') {
    mediaRecorder.stop();
  }
  isRecording = false;
  const btn = document.getElementById('btn-record');
  btn.classList.remove('recording');
  btn.textContent = '🎙️';
  btn.title = 'Registra nota vocale';
  document.getElementById('rec-bar').textContent = '';
}

async function sendVoice(blob) {
  removeWelcome();
  const typing = addTyping();
  setInputDisabled(true);

  const ext = blob.type.includes('webm') ? 'webm' : 'ogg';
  const form = new FormData();
  form.append('audio', blob, `voice.${ext}`);
  form.append('session_id', sessionId);

  try {
    const res = await fetch('/api/voice', { method: 'POST', body: form });
    const data = await res.json();
    typing.remove();
    if (res.ok) {
      addMessage('user', escapeHtml(data.transcription), '🎙️ Nota vocale trascritta');
      addMessage('ai', renderMarkdown(data.response ?? ''));
    } else {
      addMessage('ai', `<span style="color:var(--error)">⚠️ Errore: ${escapeHtml(data.detail ?? 'sconosciuto')}</span>`);
    }
  } catch (err) {
    typing.remove();
    addMessage('ai', `<span style="color:var(--error)">⚠️ Errore invio audio: ${escapeHtml(err.message)}</span>`);
  } finally {
    setInputDisabled(false);
  }
}

// ── New chat ──────────────────────────────────────────────────────────────────
function newChat() {
  // Reset server-side session
  fetch('/api/reset', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ session_id: sessionId }),
  });

  // New session ID
  sessionId = makeSessionId();
  document.getElementById('session-label').textContent = 'Sessione: ' + sessionId.slice(-8);

  // Clear UI
  const chat = document.getElementById('chat');
  chat.innerHTML = `
    <div class="welcome" id="welcome">
      <div class="welcome-icon">🤖</div>
      <h2>Ciao! Sono FbClaw</h2>
      <p>Puoi scrivermi un messaggio di testo oppure registrare una nota vocale con il pulsante 🎙️ — la trascrivo automaticamente con Groq Whisper.</p>
      <div class="welcome-chips">
        <span class="chip" onclick="quickSend('Ciao! Come funzioni?')">👋 Come funzioni?</span>
        <span class="chip" onclick="quickSend('Spiegami cosa sono i microservizi')">🧩 Microservizi</span>
        <span class="chip" onclick="quickSend('Scrivi un esempio di Dockerfile')">🐳 Dockerfile</span>
        <span class="chip" onclick="quickSend('Che modello AI usi?')">🧠 Che modello sei?</span>
      </div>
    </div>`;
}

// ── UI helpers ────────────────────────────────────────────────────────────────
function addMessage(role, htmlContent, voiceTag = null) {
  const chat = document.getElementById('chat');
  const msg = document.createElement('div');
  msg.className = `msg ${role}`;

  const avatar = document.createElement('div');
  avatar.className = 'avatar';
  avatar.textContent = role === 'user' ? '👤' : '🤖';

  const bubble = document.createElement('div');
  bubble.className = 'bubble';

  if (voiceTag) {
    const tag = document.createElement('div');
    tag.className = 'voice-tag';
    tag.textContent = voiceTag;
    bubble.appendChild(tag);
  }

  const content = document.createElement('div');
  content.innerHTML = htmlContent;
  bubble.appendChild(content);

  msg.appendChild(avatar);
  msg.appendChild(bubble);
  chat.appendChild(msg);
  chat.scrollTop = chat.scrollHeight;
  return msg;
}

function addTyping() {
  const chat = document.getElementById('chat');
  const msg = document.createElement('div');
  msg.className = 'msg ai typing';
  msg.innerHTML = `
    <div class="avatar">🤖</div>
    <div class="bubble">
      <div class="dots">
        <span class="dot"></span><span class="dot"></span><span class="dot"></span>
      </div>
    </div>`;
  chat.appendChild(msg);
  chat.scrollTop = chat.scrollHeight;
  return msg;
}

function removeWelcome() {
  document.getElementById('welcome')?.remove();
}

function setInputDisabled(disabled) {
  document.getElementById('btn-send').disabled = disabled;
  document.getElementById('btn-record').disabled = disabled;
  input.disabled = disabled;
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function renderMarkdown(text) {
  if (typeof marked !== 'undefined') {
    return marked.parse(text);
  }
  // Fallback: solo escaping + newline
  return escapeHtml(text).replace(/\n/g, '<br>');
}
