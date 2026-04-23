import os
import httpx

PAGES_QUERY = """
query ListPages($limit: Int!, $orderBy: PageOrderBy) {
  pages {
    list(limit: $limit, orderBy: $orderBy) {
      id
      path
      title
      updatedAt
    }
  }
}
"""

PAGE_CONTENT_QUERY = """
query GetPage($id: Int!) {
  pages {
    single(id: $id) {
      id
      path
      title
      content
      updatedAt
    }
  }
}
"""


class WikiJSClient:
    def __init__(self) -> None:
        self.base_url = os.environ["WIKIJS_URL"].rstrip("/")
        self.token = os.environ["WIKIJS_API_TOKEN"]
        self._http = httpx.Client(
            base_url=self.base_url,
            headers={"Authorization": f"Bearer {self.token}"},
            timeout=30,
        )

    def _gql(self, query: str, variables: dict | None = None) -> dict:
        response = self._http.post(
            "/graphql",
            json={"query": query, "variables": variables or {}},
        )
        response.raise_for_status()
        data = response.json()
        if "errors" in data:
            raise RuntimeError(f"WikiJS GraphQL error: {data['errors']}")
        return data["data"]

    def list_pages(self, limit: int = 1000) -> list[dict]:
        """Return all published pages (id, path, title, updatedAt)."""
        data = self._gql(PAGES_QUERY, {"limit": limit, "orderBy": "UPDATED"})
        return data["pages"]["list"]

    def get_page(self, page_id: int) -> dict:
        """Return full page including Markdown content."""
        data = self._gql(PAGE_CONTENT_QUERY, {"id": page_id})
        return data["pages"]["single"]

    def close(self) -> None:
        self._http.close()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()
