"""
Embed structured curriculum records (from extract_pdf.py) and load them into Qdrant.

Embeds `indicator_text + exemplar` (what a student question should match against).
grade/subject/strand/content_standard_code/indicator_code are stored as payload
metadata for filtered retrieval.

Run: python src/embed_and_load.py data/structured/mathematics-upper-primary.json --collection curriculum
"""

import argparse
import json
import os
import uuid

from dotenv import load_dotenv
from fastembed import TextEmbedding
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, PointStruct, VectorParams

load_dotenv()

EMBEDDING_MODEL = "BAAI/bge-small-en-v1.5"  # 384-dim, good quality/speed tradeoff, local/ONNX
VECTOR_SIZE = 384


def load_records(path: str):
    with open(path) as f:
        return json.load(f)


def ensure_collection(client: QdrantClient, name: str):
    if not client.collection_exists(name):
        client.create_collection(
            collection_name=name,
            vectors_config=VectorParams(size=VECTOR_SIZE, distance=Distance.COSINE),
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_json")
    parser.add_argument("--collection", default="curriculum")
    args = parser.parse_args()

    records = load_records(args.input_json)
    if not records:
        print("No records to embed.")
        return

    texts = [f"{r['indicator_text']} {r['exemplar']}".strip() for r in records]

    print(f"Embedding {len(texts)} records with {EMBEDDING_MODEL}...")
    embedder = TextEmbedding(model_name=EMBEDDING_MODEL)
    vectors = list(embedder.embed(texts))

    client = QdrantClient(
        url=os.environ["QDRANT_API_URL"],
        api_key=os.environ["QDRANT_API_SECRET"],
        timeout=60,
    )
    ensure_collection(client, args.collection)

    points = [
        PointStruct(
            id=str(uuid.uuid4()),
            vector=vector.tolist(),
            payload=record,
        )
        for record, vector in zip(records, vectors)
    ]

    client.upsert(collection_name=args.collection, points=points)
    print(f"Loaded {len(points)} points into Qdrant collection '{args.collection}'.")


if __name__ == "__main__":
    main()
