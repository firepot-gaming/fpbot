import logging
import os
from datetime import datetime, timezone

from ..wiki.client import WikiJSClient
from ..db.pages import upsert_pages

logger = logging.getLogger(__name__)

WIKIJS_URL = os.environ.get("WIKIJS_URL", "")


def build_page_url(path: str) -> str:
    return f"{WIKIJS_URL.rstrip('/')}/{path.lstrip('/')}"


def sync_all(dry_run: bool = False) -> dict:
    """
    Pull all pages from WikiJS and upsert into Supabase.
    Returns a summary dict with counts.
    """
    with WikiJSClient() as wiki:
        page_list = wiki.list_pages()
        logger.info("Found %d pages in WikiJS", len(page_list))

        if dry_run:
            for p in page_list:
                print(f"  [{p['id']}] {p['path']} — {p['title']}")
            return {"total": len(page_list), "dry_run": True}

        pages_to_upsert = []
        errors = []

        for item in page_list:
            try:
                page = wiki.get_page(int(item["id"]))
                pages_to_upsert.append(
                    {
                        "id": str(page["id"]),
                        "path": page["path"],
                        "title": page["title"],
                        "content": page["content"] or "",
                        "updated_at": page["updatedAt"],
                        "synced_at": datetime.now(timezone.utc).isoformat(),
                        "url": build_page_url(page["path"]),
                    }
                )
            except Exception as exc:
                logger.warning("Failed to fetch page %s: %s", item["id"], exc)
                errors.append(item["id"])

        # Upsert in batches of 100 to avoid request size limits
        upserted = 0
        batch_size = 100
        for i in range(0, len(pages_to_upsert), batch_size):
            batch = pages_to_upsert[i : i + batch_size]
            upserted += upsert_pages(batch)

        summary = {
            "total": len(page_list),
            "upserted": upserted,
            "errors": len(errors),
            "error_ids": errors,
        }
        logger.info("Sync complete: %s", summary)
        return summary
