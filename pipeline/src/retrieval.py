"""Shared embed-and-retrieve logic, used by both query_rag.py (terminal test) and service.py (API)."""

import difflib
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


_PHOTO_QUOTE_RE = re.compile(r"\A> \*\*[^*]+\*\*\n((?:>.*(?:\n|\Z))+)")
_MOVED_ON_RE = re.compile(r"\b(?:question|number|no\.?)\s*([2-9]|1\d)\b|\bnext (?:question|one)\b|\bsecond (?:question|one)\b", re.I)
_NUMBERED_LINE_RE = re.compile(r"^\s*(?:q(?:uestion)?\s*)?\d+[.):]", re.I)


def split_photo_reply(assistant_message: str) -> tuple[str, str] | None:
    """(questions quoted at the top of a reply to a homework photo, the tutor's own text)."""
    m = _PHOTO_QUOTE_RE.match(assistant_message)
    if not m:
        return None
    lines = [line[1:].strip() for line in m.group(1).splitlines()]
    quote = "\n".join(l for l in lines if l and not l.lower().startswith("student's working"))
    return (quote, assistant_message[m.end():].strip()) if quote else None


def _first_question(quote: str) -> str:
    """Heading/instruction plus question 1 — what the tutor starts on."""
    kept, numbered = [], 0
    for line in quote.splitlines():
        if _NUMBERED_LINE_RE.match(line):
            numbered += 1
            if numbered > 1:
                break
        kept.append(line)
    return " ".join(kept)


def build_retrieval_query(question: str, history: list[dict] | None = None) -> str:
    """
    The text to search the curriculum with. A bare reply to a tutoring question ("yes", "5",
    "I don't know") or a short pronoun follow-up ("why does that work?") says nothing about the
    topic, so anchor it to what the conversation is about. A message that states its own topic
    is searched on its own, so switching topics mid-chat re-grounds.

    The anchor is the student's most recent substantive question. After a homework photo it is
    the photo's first question plus the tutor's last message, which names the problem being
    worked on right now — so moving on to "question 2" re-grounds on question 2.
    """
    words = _WORD_RE.findall(question)
    anchor, photo_question, tutor_text = None, None, ""
    for turn in history or []:
        content = turn.get("content", "")
        if turn.get("role") == "user" and len(_WORD_RE.findall(content)) >= 5:
            anchor, photo_question = content, None  # a typed question replaces any photo
        elif turn.get("role") == "assistant":
            photo = split_photo_reply(content)
            if photo:
                photo_question, tutor_text = _first_question(photo[0]), photo[1]
            elif photo_question:
                tutor_text = content  # the tutor's latest message names the current problem
    if photo_question:
        # Once the tutor has moved on ("let's try question 2"), question 1 is stale: only the
        # tutor's message names the problem now being worked on.
        moved_on = _MOVED_ON_RE.search(tutor_text)
        anchor = tutor_text[:240] if moved_on else f"{photo_question} {tutor_text[:240]}"
    if anchor and (len(words) <= 4 or (len(words) <= 7 and _FOLLOWUP_RE.search(question))):
        return f"{anchor} {question}"
    return question


_VOCAB_FIELDS = ("indicator_text", "content_standard_text", "substrand", "exemplar")
_TOKEN_RE = re.compile(r"[A-Za-z]{5,}")


def vocabulary_from_records(records: list[dict]) -> set[str]:
    words: set[str] = set()
    for r in records:
        for field in _VOCAB_FIELDS:
            words.update(w.lower() for w in _TOKEN_RE.findall(r.get(field) or ""))
    return words


@lru_cache
def curriculum_vocabulary(collection: str = "curriculum") -> frozenset[str]:
    """Every word of 5+ letters in the indexed curriculum, read once from Qdrant."""
    client = get_qdrant_client()
    records, offset = [], None
    while True:
        batch, offset = client.scroll(
            collection, limit=256, offset=offset, with_payload=list(_VOCAB_FIELDS), with_vectors=False
        )
        records += [p.payload for p in batch]
        if offset is None:
            return frozenset(vocabulary_from_records(records))


def correct_spelling(text: str, vocabulary) -> str:
    """
    Fix likely typos in a search query ("fractons" -> "fractions") using the curriculum's own
    vocabulary. Only words of 5+ letters that the curriculum never uses are touched, and only
    when a very close curriculum word exists, so ordinary words and names pass through. Used for
    the search query only — the student's own words still go to the model unchanged.
    """

    def fix(m: re.Match) -> str:
        word = m.group(0)
        low = word.lower()
        if low in vocabulary:
            return word
        close = difflib.get_close_matches(
            low, [v for v in vocabulary if v[0] == low[0] and abs(len(v) - len(low)) <= 2], n=1, cutoff=0.85
        )
        return close[0] if close else word

    return _TOKEN_RE.sub(fix, text)


# Everyday phrases students use where the curriculum uses different words (checked against the
# indexed text: e.g. "figure of speech" appears nowhere, "literary devices" 4 times). The
# curriculum term is appended to the search query, never replacing the student's words.
# Add entries only after confirming the mismatch against the data (see eval/run_eval.py).
STUDENT_TERMS = [
    (re.compile(r"\bfigures? of speech\b", re.I), "literary devices figurative language"),
    (re.compile(r"\btimes? tables?\b", re.I), "multiplication"),
    (re.compile(r"\btake ?away\b", re.I), "subtraction"),
    (re.compile(r"\bfull stops?\b", re.I), "punctuation"),
    (re.compile(r"\blong division\b", re.I), "division"),
]


def expand_student_terms(text: str) -> str:
    extra = [curriculum_term for pattern, curriculum_term in STUDENT_TERMS if pattern.search(text)]
    return f"{text} {' '.join(extra)}" if extra else text


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
