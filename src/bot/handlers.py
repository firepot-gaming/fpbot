import logging
import re

from slack_bolt import App

from ..db.pages import search_pages
from ..bot.responder import answer

logger = logging.getLogger(__name__)


def clean_question(text: str, bot_user_id: str) -> str:
    """Remove bot mention and trim whitespace from message text."""
    cleaned = re.sub(rf"<@{re.escape(bot_user_id)}>", "", text).strip()
    return cleaned


def register(app: App, bot_user_id: str) -> None:
    @app.event("app_mention")
    def handle_mention(event, say, client):
        raw_text = event.get("text", "")
        question = clean_question(raw_text, bot_user_id)

        if not question:
            say(
                text="Oi! Me manda uma pergunta que busco na wiki para você. Ex: `@fpbot como solicitar reembolso?`",
                thread_ts=event["ts"],
            )
            return

        logger.info("Question received: %s", question)

        # Acknowledge immediately — Slack timeout is 3s
        say(text="🔍 Buscando na wiki...", thread_ts=event["ts"])

        try:
            pages = search_pages(question, limit=3)
            response_text = answer(question, pages)
        except Exception as exc:
            logger.exception("Error generating answer: %s", exc)
            response_text = "Ops, tive um problema ao buscar na wiki. Tenta de novo em instantes."

        say(text=response_text, thread_ts=event["ts"])
