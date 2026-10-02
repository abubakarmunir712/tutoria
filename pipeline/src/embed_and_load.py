"""
Embed structured curriculum records (from extract_pdf.py / extract_shs.py) and load them
into Qdrant.

Embeds `indicator_text + exemplar` (what a student question should match against).
grade/subject/strand/content_standard_code/indicator_code are stored as payload
metadata for filtered retrieval.

Loading is idempotent: point ids are derived from (phase, subject, grade, indicator_code)
and any existing points for the same subject + phase are replaced, so re-running after an
extractor fix never leaves stale or duplicate points behind.

Run: python src/embed_and_load.py data/structured/mathematics-upper-primary.json --collection curriculum
"""

import argparse
import json
import os
import uuid

from dotenv import load_dotenv
from fastembed import TextEmbedding
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, FieldCondition, Filter, MatchValue, PointStruct, VectorParams

load_dotenv()

EMBEDDING_MODEL = "BAAI/bge-small-en-v1.5"  # 384-dim, good quality/speed tradeoff, local/ONNX
VECTOR_SIZE = 384
BATCH_SIZE = 64
ID_NAMESPACE = uuid.UUID("5f0c1d52-7f8e-4a53-9a3e-1f6a6d1d2c10")


def load_records(path: str):
    with open(path) as f:
        return json.load(f)


def get_client() -> QdrantClient:
    return QdrantClient(
        url=os.environ["QDRANT_API_URL"],
        api_key=os.environ["QDRANT_API_SECRET"],
        timeout=60,
    )


def ensure_collection(client: QdrantClient, name: str):
    if not client.collection_exists(name):
        client.create_collection(
            collection_name=name,
            vectors_config=VectorParams(size=VECTOR_SIZE, distance=Distance.COSINE),
        )


def point_id(record: dict) -> str:
    key = f"{record['phase']}|{record['subject']}|{record['grade']}|{record['indicator_code']}"
    return str(uuid.uuid5(ID_NAMESPACE, key))


def embed_records(records: list[dict], embedder: TextEmbedding | None = None):
    embedder = embedder or TextEmbedding(model_name=EMBEDDING_MODEL)
    texts = [f"{r['indicator_text']} {r['exemplar']}".strip() for r in records]
    return list(embedder.embed(texts))


def replace_subject_phase(client: QdrantClient, collection: str, records: list[dict], vectors) -> int:
    """Delete existing points for this records' subject + phase, then upsert the new ones."""
    ensure_collection(client, collection)
    subject, phase = records[0]["subject"], records[0]["phase"]
    client.delete(
        collection_name=collection,
        points_selector=Filter(
            must=[
                FieldCondition(key="subject", match=MatchValue(value=subject)),
                FieldCondition(key="phase", match=MatchValue(value=phase)),
            ]
        ),
    )
    points = [
        PointStruct(id=point_id(r), vector=v.tolist(), payload=r) for r, v in zip(records, vectors)
    ]
    for i in range(0, len(points), BATCH_SIZE):
        client.upsert(collection_name=collection, points=points[i : i + BATCH_SIZE])
    return len(points)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_json")
    parser.add_argument("--collection", default="curriculum")
    args = parser.parse_args()

    records = load_records(args.input_json)
    if not records:
        print("No records to embed.")
        return

    print(f"Embedding {len(records)} records with {EMBEDDING_MODEL}...")
    vectors = embed_records(records)
    n = replace_subject_phase(get_client(), args.collection, records, vectors)
    print(f"Loaded {n} points into Qdrant collection '{args.collection}'.")


if __name__ == "__main__":
    main()
