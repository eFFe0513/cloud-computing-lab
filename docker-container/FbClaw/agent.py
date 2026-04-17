"""
agent.py — FbClaw AI Agent
Gestisce le sessioni in memoria usando il framework Agno + Mistral come LLM.
"""
import os
import threading
from agno.agent import Agent
from agno.models.mistral import MistralChat

# In-memory session store: session_id → Agent instance
_sessions: dict[str, Agent] = {}
_lock = threading.Lock()


def get_or_create_agent(session_id: str) -> Agent:
    """
    Restituisce l'Agent esistente per session_id o ne crea uno nuovo.
    Ogni Agent mantiene la propria cronologia conversazione in memoria.
    """
    with _lock:
        if session_id not in _sessions:
            _sessions[session_id] = Agent(
                name="FbClaw",
                model=MistralChat(
                    id=os.getenv("MISTRAL_MODEL", "mistral-large-latest"),
                    api_key=os.getenv("MISTRAL_API_KEY"),
                ),
                description=(
                    "Sei FbClaw, un assistente AI intelligente e versatile creato da Filippo Bilardo. "
                    "Rispondi sempre nella lingua dell'utente (italiano o inglese). "
                    "Quando ricevi messaggi con il prefisso [Nota vocale], specifica che si "
                    "tratta di una nota vocale trascritta automaticamente con Groq Whisper."
                ),
                instructions=[
                    "Sii conciso e diretto nelle risposte.",
                    "Usa il markdown quando utile (elenchi, codice, grassetto).",
                    "Per domande tecniche, fornisci sempre esempi pratici.",
                    "Se non sai qualcosa, dillo chiaramente senza inventare.",
                ],
                add_history_to_messages=True,
                num_history_responses=10,
                markdown=True,
            )
            print(f"[FbClaw] Nuova sessione creata: {session_id}")
        return _sessions[session_id]


def reset_session(session_id: str) -> None:
    """Rimuove l'Agent per session_id, azzerando la cronologia."""
    with _lock:
        if session_id in _sessions:
            del _sessions[session_id]
            print(f"[FbClaw] Sessione resettata: {session_id}")


def active_sessions() -> int:
    with _lock:
        return len(_sessions)
