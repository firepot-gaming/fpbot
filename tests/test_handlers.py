"""Unit tests for message handler utilities."""
from src.bot.handlers import clean_question


def test_clean_question_removes_mention():
    result = clean_question("<@U12345> como tiro férias?", "U12345")
    assert result == "como tiro férias?"


def test_clean_question_multiple_spaces():
    result = clean_question("<@U12345>   pergunta aqui  ", "U12345")
    assert result == "pergunta aqui"


def test_clean_question_no_mention():
    result = clean_question("só o texto", "U12345")
    assert result == "só o texto"
