"""
telegram_bot.py — FbClaw Telegram Bot
Gestisce messaggi di testo e note vocali via Telegram.
Si avvia come thread daemon da main.py se TELEGRAM_BOT_TOKEN è configurato.
"""
import os
import asyncio
import logging

from telegram import Update
from telegram.ext import (
    Application,
    CommandHandler,
    MessageHandler,
    filters,
    ContextTypes,
)
from groq import Groq

from agent import get_or_create_agent, reset_session

logger = logging.getLogger(__name__)
groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))


# ── Command handlers ──────────────────────────────────────────────────────────
async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await update.message.reply_text(
        "👋 Ciao! Sono *FbClaw*, il tuo assistente AI.\n\n"
        "Puoi inviarmi:\n"
        "• 💬 Messaggi di testo\n"
        "• 🎙️ Note vocali \\(trascritte con Groq Whisper\\)\n\n"
        "Comandi:\n"
        "/start — Questo messaggio\n"
        "/reset — Nuova conversazione\n"
        "/info — Info sul modello",
        parse_mode="MarkdownV2",
    )


async def cmd_reset(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    session_id = f"tg-{update.effective_user.id}"
    reset_session(session_id)
    await update.message.reply_text("🔄 Conversazione resettata! Ricominciamo da capo.")


async def cmd_info(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    model = os.getenv("MISTRAL_MODEL", "mistral-large-latest")
    await update.message.reply_text(
        f"ℹ️ *FbClaw Agent*\n\n"
        f"🧠 LLM: `{model}` \\(Mistral\\)\n"
        f"🎙️ Trascrizione: Groq Whisper large\\-v3\n"
        f"🤖 Framework: Agno",
        parse_mode="MarkdownV2",
    )


# ── Message handlers ──────────────────────────────────────────────────────────
async def handle_text(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    session_id = f"tg-{update.effective_user.id}"
    await update.message.chat.send_action("typing")

    agent = get_or_create_agent(session_id)
    try:
        response = agent.run(update.message.text, stream=False)
        content = response.content or "Non ho ricevuto una risposta."
        await update.message.reply_text(content)
    except Exception as e:
        logger.error(f"Agent error [{session_id}]: {e}")
        await update.message.reply_text(f"⚠️ Errore: {e}")


async def handle_voice(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    session_id = f"tg-{update.effective_user.id}"
    await update.message.chat.send_action("typing")

    # Scarica il file OGG da Telegram
    voice_file = await update.message.voice.get_file()
    audio_bytes = await voice_file.download_as_bytearray()

    # Trascrizione con Groq Whisper
    try:
        transcription = groq_client.audio.transcriptions.create(
            file=("voice.ogg", bytes(audio_bytes)),
            model="whisper-large-v3",
            response_format="text",
        )
    except Exception as e:
        await update.message.reply_text(f"⚠️ Errore trascrizione: {e}")
        return

    await update.message.reply_text(f"🎙️ Hai detto: {transcription}")

    # Invia all'agente
    agent = get_or_create_agent(session_id)
    try:
        await update.message.chat.send_action("typing")
        response = agent.run(f"[Nota vocale]: {transcription}", stream=False)
        await update.message.reply_text(response.content)
    except Exception as e:
        logger.error(f"Agent voice error [{session_id}]: {e}")
        await update.message.reply_text(f"⚠️ Errore agente: {e}")


# ── Bot runner ────────────────────────────────────────────────────────────────
async def _run_bot() -> None:
    token = os.getenv("TELEGRAM_BOT_TOKEN")
    app = Application.builder().token(token).build()

    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("reset", cmd_reset))
    app.add_handler(CommandHandler("info", cmd_info))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))
    app.add_handler(MessageHandler(filters.VOICE, handle_voice))

    print("[Telegram] Bot avviato, in attesa di messaggi...")
    async with app:
        await app.start()
        await app.updater.start_polling(allowed_updates=Update.ALL_TYPES)
        # Attende indefinitamente (finché il thread non viene terminato)
        await asyncio.Event().wait()


def start_bot_thread() -> None:
    """Avvia il bot in un loop asyncio dedicato (chiamato da un daemon thread)."""
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        loop.run_until_complete(_run_bot())
    except Exception as e:
        print(f"[Telegram] Bot terminato con errore: {e}")
    finally:
        loop.close()
