"""Unit tests for the responder module (no API calls)."""
from datetime import datetime
from unittest.mock import MagicMock, patch

from src.db.pages import WikiPage
from src.bot.responder import build_context, answer


def make_page(title: str, content: str, url: str = "https://wiki.test/page") -> WikiPage:
    return WikiPage(
        id="1",
        path="/test",
        title=title,
        content=content,
        updated_at=datetime(2026, 1, 1),
        url=url,
    )


def test_build_context_empty():
    assert build_context([]) == ""


def test_build_context_single_page():
    page = make_page("Política de Férias", "30 dias após 12 meses.")
    ctx = build_context([page])
    assert "Política de Férias" in ctx
    assert "30 dias" in ctx
    assert "https://wiki.test/page" in ctx


def test_answer_no_pages_returns_fallback():
    result = answer("como tiro férias?", [])
    assert "wiki" in result.lower()


def test_answer_calls_claude_with_context():
    pages = [make_page("Férias", "30 dias CLT.", "https://wiki.test/ferias")]
    fake_response = MagicMock()
    fake_response.content = [MagicMock(text="Você tem 30 dias de férias. 📄 Fonte: https://wiki.test/ferias")]

    with patch("src.bot.responder._get_client") as mock_get_client:
        mock_client = MagicMock()
        mock_client.messages.create.return_value = fake_response
        mock_get_client.return_value = mock_client

        result = answer("como tiro férias?", pages)

    assert "30 dias" in result
    mock_client.messages.create.assert_called_once()
