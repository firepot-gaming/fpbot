from dataclasses import dataclass
from datetime import datetime

from .client import get_client


@dataclass
class WikiPage:
    id: str
    path: str
    title: str
    content: str
    updated_at: datetime
    url: str


def upsert_pages(pages: list[dict]) -> int:
    """Insert or update wiki pages. Returns count of upserted rows."""
    if not pages:
        return 0
    client = get_client()
    result = (
        client.table("wiki_pages")
        .upsert(pages, on_conflict="id")
        .execute()
    )
    return len(result.data)


def search_pages(query: str, limit: int = 5) -> list[WikiPage]:
    """Full-text search over wiki pages using PostgreSQL tsvector."""
    client = get_client()
    result = client.rpc(
        "search_wiki_pages",
        {"query_text": query, "result_limit": limit},
    ).execute()

    pages = []
    for row in result.data:
        pages.append(
            WikiPage(
                id=row["id"],
                path=row["path"],
                title=row["title"],
                content=row["content"],
                updated_at=datetime.fromisoformat(row["updated_at"]),
                url=row["url"],
            )
        )
    return pages


def get_all_page_ids() -> list[str]:
    """Return all page IDs currently in the database (for diff on sync)."""
    client = get_client()
    result = client.table("wiki_pages").select("id").execute()
    return [row["id"] for row in result.data]
