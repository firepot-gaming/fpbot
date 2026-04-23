import os
import anthropic

from ..db.pages import WikiPage

_client: anthropic.Anthropic | None = None

SYSTEM_PROMPT = """Você é o fpbot, assistente interno da Firepot.
Responda a pergunta do colaborador com base EXCLUSIVAMENTE no conteúdo da wiki fornecido.
Se a informação não estiver no conteúdo, diga claramente: "Não encontrei essa informação na wiki."
Seja direto e objetivo. Máximo 300 palavras.
Sempre termine com a linha: "📄 Fonte: <url da página mais relevante>"
"""


def _get_client() -> anthropic.Anthropic:
    global _client
    if _client is None:
        _client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
    return _client


def build_context(pages: list[WikiPage]) -> str:
    if not pages:
        return ""
    parts = []
    for page in pages:
        parts.append(
            f"## {page.title}\nURL: {page.url}\n\n{page.content}"
        )
    return "\n\n---\n\n".join(parts)


def answer(question: str, pages: list[WikiPage]) -> str:
    """Generate a Claude-powered answer grounded in wiki pages."""
    context = build_context(pages)

    if not context:
        return (
            "Não encontrei nada na wiki relacionado à sua pergunta. "
            "Tente reformular ou consulte a wiki diretamente."
        )

    user_message = f"Conteúdo da wiki:\n\n{context}\n\n---\n\nPergunta: {question}"

    response = _get_client().messages.create(
        model="claude-sonnet-4-6",
        max_tokens=600,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_message}],
    )
    return response.content[0].text
