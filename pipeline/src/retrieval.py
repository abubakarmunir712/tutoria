"""Shared embed-and-retrieve logic, used by both query_rag.py (terminal test) and service.py (API)."""

import os
import re
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


# Best-match cosine score below which nothing in the grade/subject really matches the question.
# On-topic questions score 0.56-0.8 (median ~0.71) and off-topic ones 0.45-0.69, so this can't
# gate retrieval — it only lets the model be told the match is weak.
WEAK_MATCH_SCORE = 0.58

_WORD_RE = re.compile(r"\w+")
_FOLLOWUP_RE = re.compile(
    r"\b(it|that|this|those|these|they|them|why|how come|again|more|example|examples|next|so|then)\b", re.I
)


def build_retrieval_query(question: str, history: list[dict] | None = None) -> str:
    """
    The text to search the curriculum with. A bare reply to a tutoring question ("yes", "5",
    "I don't know") or a pronoun follow-up ("why does that work?") says nothing about the
    topic, so anchor it to the student's most recent substantive question. A message that
    states its own topic is searched on its own, so switching topics mid-chat re-grounds.
    """
    words = _WORD_RE.findall(question)
    anchors = [
        h["content"]
        for h in (history or [])
        if h.get("role") == "user" and len(_WORD_RE.findall(h.get("content", ""))) >= 5
    ]
    if anchors and (len(words) <= 4 or (len(words) <= 10 and _FOLLOWUP_RE.search(question))):
        return f"{anchors[-1]} {question}"
    return question


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
