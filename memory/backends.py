"""
Vector store backend abstraction.

Supports:
  - chroma: local, per-developer (default)
  - pgvector: shared PostgreSQL, team-wide memory

Both implement the same interface so index.py and query.py work
transparently with either backend.
"""

import os
from pathlib import Path


class VectorBackend:
    """Common interface for vector stores."""

    def add(self, ids: list[str], embeddings: list[list[float]],
            documents: list[str], metadatas: list[dict]):
        raise NotImplementedError

    def query(self, embedding: list[float], top_k: int = 5,
              where: dict | None = None) -> dict:
        raise NotImplementedError

    def get(self, where: dict | None = None, ids: list[str] | None = None) -> dict:
        raise NotImplementedError

    def delete(self, ids: list[str]):
        raise NotImplementedError

    def count(self) -> int:
        raise NotImplementedError

    def get_all_metadatas(self) -> list[dict]:
        raise NotImplementedError


# -----------------------------------------------------------------------
# Chroma backend
# -----------------------------------------------------------------------

class ChromaBackend(VectorBackend):
    def __init__(self, config: dict):
        import chromadb

        project_root = Path(__file__).parent.parent.resolve()
        persist_dir = project_root / config["persist_dir"]
        collection_name = config.get("collection_name", "project_memory")

        self.client = chromadb.PersistentClient(path=str(persist_dir))
        self.collection = self.client.get_or_create_collection(
            name=collection_name,
            metadata={"hnsw:space": "cosine"},
        )

    def add(self, ids, embeddings, documents, metadatas):
        self.collection.add(
            ids=ids, embeddings=embeddings,
            documents=documents, metadatas=metadatas,
        )

    def query(self, embedding, top_k=5, where=None):
        return self.collection.query(
            query_embeddings=[embedding],
            n_results=top_k,
            where=where,
            include=["documents", "metadatas", "distances"],
        )

    def get(self, where=None, ids=None):
        kwargs = {"include": ["metadatas"]}
        if where:
            kwargs["where"] = where
        if ids:
            kwargs["ids"] = ids
        return self.collection.get(**kwargs)

    def delete(self, ids):
        self.collection.delete(ids=ids)

    def count(self):
        return self.collection.count()

    def get_all_metadatas(self):
        data = self.collection.get(include=["metadatas"])
        return data["metadatas"]


# -----------------------------------------------------------------------
# pgvector backend
# -----------------------------------------------------------------------

class PgvectorBackend(VectorBackend):
    """
    Shared PostgreSQL backend via pgvector.
    Requires: pip install psycopg2-binary pgvector

    All team members point to the same database, so everyone
    shares the same long-term memory.

    Schema created automatically on first use:
        CREATE EXTENSION IF NOT EXISTS vector;
        CREATE TABLE IF NOT EXISTS <table_name> (
            id TEXT PRIMARY KEY,
            embedding vector(<dimensions>),
            document TEXT,
            metadata JSONB,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );
    """

    def __init__(self, config: dict):
        import psycopg2
        from psycopg2.extras import Json, execute_values

        pg = config["pgvector"]
        password = os.environ.get(pg.get("password_env", "PGVECTOR_PASSWORD"), "")

        self.conn = psycopg2.connect(
            host=pg["host"],
            port=pg.get("port", 5432),
            dbname=pg["database"],
            user=pg["user"],
            password=password,
        )
        self.conn.autocommit = True
        self.table = pg.get("table_name", "embeddings")
        self.dimensions = config.get("embedding_dimensions", 384)
        self._Json = Json
        self._execute_values = execute_values

        self._ensure_schema()

    def _ensure_schema(self):
        with self.conn.cursor() as cur:
            cur.execute("CREATE EXTENSION IF NOT EXISTS vector;")
            cur.execute(f"""
                CREATE TABLE IF NOT EXISTS {self.table} (
                    id TEXT PRIMARY KEY,
                    embedding vector({self.dimensions}),
                    document TEXT,
                    metadata JSONB DEFAULT '{{}}'::jsonb,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                );
            """)
            cur.execute(f"""
                CREATE INDEX IF NOT EXISTS idx_{self.table}_embedding
                ON {self.table} USING ivfflat (embedding vector_cosine_ops)
                WITH (lists = 100);
            """)

    def add(self, ids, embeddings, documents, metadatas):
        rows = []
        for id_, emb, doc, meta in zip(ids, embeddings, documents, metadatas):
            rows.append((id_, emb, doc, self._Json(meta)))

        with self.conn.cursor() as cur:
            self._execute_values(
                cur,
                f"""INSERT INTO {self.table} (id, embedding, document, metadata)
                    VALUES %s
                    ON CONFLICT (id) DO UPDATE SET
                        embedding = EXCLUDED.embedding,
                        document = EXCLUDED.document,
                        metadata = EXCLUDED.metadata,
                        created_at = NOW()""",
                rows,
                template=f"(%s, %s::vector({self.dimensions}), %s, %s)",
            )

    def query(self, embedding, top_k=5, where=None):
        emb_str = "[" + ",".join(str(x) for x in embedding) + "]"

        where_clause = ""
        if where:
            conditions = []
            for k, v in where.items():
                conditions.append(f"metadata->>'{k}' = '{v}'")
            where_clause = "WHERE " + " AND ".join(conditions)

        with self.conn.cursor() as cur:
            cur.execute(f"""
                SELECT id, document, metadata,
                       1 - (embedding <=> '{emb_str}'::vector({self.dimensions})) as similarity
                FROM {self.table}
                {where_clause}
                ORDER BY embedding <=> '{emb_str}'::vector({self.dimensions})
                LIMIT {top_k}
            """)
            rows = cur.fetchall()

        ids = [r[0] for r in rows]
        documents = [r[1] for r in rows]
        metadatas = [r[2] for r in rows]
        # Convert similarity to distance (1 - similarity) for Chroma-compatible interface
        distances = [1 - r[3] for r in rows]

        return {
            "ids": [ids],
            "documents": [documents],
            "metadatas": [metadatas],
            "distances": [distances],
        }

    def get(self, where=None, ids=None):
        conditions = []
        if where:
            for k, v in where.items():
                conditions.append(f"metadata->>'{k}' = '{v}'")
        if ids:
            ids_str = ",".join(f"'{i}'" for i in ids)
            conditions.append(f"id IN ({ids_str})")

        where_clause = ""
        if conditions:
            where_clause = "WHERE " + " AND ".join(conditions)

        with self.conn.cursor() as cur:
            cur.execute(f"SELECT id, metadata FROM {self.table} {where_clause}")
            rows = cur.fetchall()

        return {
            "ids": [r[0] for r in rows],
            "metadatas": [r[1] for r in rows],
        }

    def delete(self, ids):
        ids_str = ",".join(f"'{i}'" for i in ids)
        with self.conn.cursor() as cur:
            cur.execute(f"DELETE FROM {self.table} WHERE id IN ({ids_str})")

    def count(self):
        with self.conn.cursor() as cur:
            cur.execute(f"SELECT COUNT(*) FROM {self.table}")
            return cur.fetchone()[0]

    def get_all_metadatas(self):
        with self.conn.cursor() as cur:
            cur.execute(f"SELECT metadata FROM {self.table}")
            return [r[0] for r in cur.fetchall()]


# -----------------------------------------------------------------------
# Factory
# -----------------------------------------------------------------------

def create_backend(config: dict) -> VectorBackend:
    """Create the appropriate backend based on config."""
    backend_type = config.get("backend", "chroma")

    if backend_type == "chroma":
        return ChromaBackend(config)
    elif backend_type == "pgvector":
        return PgvectorBackend(config)
    else:
        raise ValueError(f"Unknown backend: {backend_type}. Use 'chroma' or 'pgvector'.")
