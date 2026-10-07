"""
Run the full curriculum pipeline for every source in curriculum_sources.py:
PDF -> structured JSON (data/structured/<slug>.json) -> embeddings -> Qdrant.

Run (from pipeline/):
  python src/ingest_all.py                      # extract + load everything
  python src/ingest_all.py --extract-only       # write JSON only, no Qdrant needed
  python src/ingest_all.py --only mathematics-jhs science-shs
  python src/ingest_all.py --skip-images        # faster, no diagram extraction (drops image links from the JSON)
  python src/ingest_all.py --from-json          # skip PDF extraction, load the existing JSON into Qdrant
"""

import argparse
import json
from dataclasses import asdict
from pathlib import Path

from curriculum_sources import SOURCES
from topic_names import apply_topic_names

ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "data" / "raw"
STRUCTURED_DIR = ROOT / "data" / "structured"
IMAGE_DIR = STRUCTURED_DIR / "images"


def extract_source(source, skip_images: bool):
    pdf = str(RAW_DIR / source.pdf)
    if source.extractor == "shs":
        from extract_shs import extract

        return extract(pdf, source.subject)
    from extract_pdf import extract

    return extract(
        pdf,
        source.subject,
        source.phase,
        image_dir=None if skip_images else IMAGE_DIR,
        image_prefix=f"{source.slug}-",
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", nargs="*", help="Source slugs to process (default: all)")
    parser.add_argument("--extract-only", action="store_true", help="Write JSON but don't load Qdrant")
    parser.add_argument("--skip-images", action="store_true")
    parser.add_argument(
        "--from-json",
        action="store_true",
        help="Don't re-extract PDFs; embed and load the existing data/structured/<slug>.json files.",
    )
    parser.add_argument("--collection", default="curriculum")
    args = parser.parse_args()

    sources = [s for s in SOURCES if not args.only or s.slug in args.only]
    if not sources:
        raise SystemExit(f"No sources match {args.only}. Known: {[s.slug for s in SOURCES]}")

    STRUCTURED_DIR.mkdir(parents=True, exist_ok=True)

    client = embedder = None
    if not args.extract_only:
        from embed_and_load import EMBEDDING_MODEL, get_client
        from fastembed import TextEmbedding

        client = get_client()
        embedder = TextEmbedding(model_name=EMBEDDING_MODEL)

    for source in sources:
        print(f"\n== {source.slug} ({source.pdf})")
        out = STRUCTURED_DIR / f"{source.slug}.json"
        if args.from_json:
            records = json.loads(out.read_text())
            print(f"   read {len(records)} records from {out.relative_to(ROOT)}")
        else:
            records = [asdict(r) for r in extract_source(source, args.skip_images)]
            renamed = apply_topic_names(source.slug, records)
            if renamed:
                print(f"   applied stored topic names to {renamed} records")
            out.write_text(json.dumps(records, indent=2))
            print(f"   extracted {len(records)} records -> {out.relative_to(ROOT)}")
        if not records:
            print("   !! no records — skipping load")
            continue

        if client:
            from embed_and_load import embed_records, replace_subject_phase

            vectors = embed_records(records, embedder)
            n = replace_subject_phase(client, args.collection, records, vectors)
            print(f"   loaded {n} points into '{args.collection}'")


if __name__ == "__main__":
    main()
