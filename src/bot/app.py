import logging
import os

from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler

from .handlers import register

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)


def create_app() -> App:
    app = App(
        token=os.environ["SLACK_BOT_TOKEN"],
        signing_secret=os.environ["SLACK_SIGNING_SECRET"],
    )

    # Fetch bot user ID to strip mentions correctly
    auth_info = app.client.auth_test()
    bot_user_id = auth_info["user_id"]
    logger.info("Bot user ID: %s", bot_user_id)

    register(app, bot_user_id)
    return app


def main() -> None:
    app = create_app()
    handler = SocketModeHandler(app, os.environ["SLACK_APP_TOKEN"])
    logger.info("fpbot starting in Socket Mode...")
    handler.start()


if __name__ == "__main__":
    main()
