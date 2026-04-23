#!/usr/bin/env python3
"""Sync WikiJS pages into Supabase. Run manually or via cron."""
import argparse
import logging
import sys
from pathlib import Path

# Allow running as script from repo root
sys.path.insert(0, str(Path(__file__).parent.parent))

from dotenv import load_dotenv
load_dotenv()

from src.wiki.sync import sync_all

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s — %(message)s",
)


def main() -> None:
    parser = argparse.ArgumentParser(description="Sync WikiJS → Supabase")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="List pages without writing to Supabase",
    )
    args = parser.parse_args()

    summary = sync_all(dry_run=args.dry_run)
    print(summary)


if __name__ == "__main__":
    main()
