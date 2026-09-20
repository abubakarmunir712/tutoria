"""Shared embed-and-retrieve logic, used by both query_rag.py (terminal test) and service.py (API)."""

import os
from functools import lru_cache

from fastembed import TextEmbedding
from qdrant_client import QdrantClient
from qdrant_client.models import FieldCondition, Filter, MatchValue

EMBEDDING_MODEL = "BAAI/bge-small-en-v1.5"
# Explicit, stable path (rather than fastembed's default under /tmp) so the Docker build
# can pre-download the model into the image — no network call / cold-start delay at runtime.
EMBEDDING_CACHE_DIR = os.environ.get("FASTEMBED_CACHE_DIR", "/app/model_cache")


@lru_cache
def get_embedder() -> TextEmbedding:
    return TextEmbedding(model_name=EMBEDDING_MODEL, cache_dir=EMBEDDING_CACHE_DIR)


@lru_cache
def get_qdrant_client() -> QdrantClient:
    return QdrantClient(
        url=os.environ["QDRANT_API_URL"],
        api_key=os.environ["QDRANT_API_SECRET"],
        timeout=30,
    )


def build_filter(grade: str | None, subject: str | None) -> Filter | None:
    conditions = []
    if grade:
        conditions.append(FieldCondition(key="grade", match=MatchValue(value=grade)))
    if subject:
        conditions.append(FieldCondition(key="subject", match=MatchValue(value=subject)))
    return Filter(must=conditions) if conditions else None


def retrieve(
    question: str,
    grade: str | None = None,
    subject: str | None = None,
    collection: str = "curriculum",
    top_k: int = 3,
) -> list[dict]:
    """Embed `question` and return the top_k matching curriculum records (with score)."""
    vector = next(get_embedder().embed([question])).tolist()
    results = get_qdrant_client().query_points(
        collection_name=collection,
        query=vector,
        query_filter=build_filter(grade, subject),
        limit=top_k,
    ).points
    return [{"score": r.score, **r.payload} for r in results]
