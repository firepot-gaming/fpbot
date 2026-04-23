#!/usr/bin/env python3
"""Apply schema.sql to Supabase. Run once to initialize the database."""
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from dotenv import load_dotenv
load_dotenv()

from supabase import create_client

SCHEMA_PATH = Path(__file__).parent.parent / "src" / "db" / "schema.sql"


def main() -> None:
    url = os.environ["SUPABASE_URL"]
    key = os.environ["SUPABASE_SERVICE_KEY"]
    client = create_client(url, key)

    sql = SCHEMA_PATH.read_text()
    # Supabase client doesn't expose raw SQL — print instructions
    print("=== Copy the SQL below and run it in the Supabase SQL Editor ===\n")
    print(sql)
    print("\n=== Or use psql: ===")
    print(f"psql $DATABASE_URL -f {SCHEMA_PATH}")


if __name__ == "__main__":
    main()
