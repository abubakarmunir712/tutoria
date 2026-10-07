"""
The curriculum's topic list for one grade and subject: strands and the sub-strands (topics)
inside them, in curriculum order, with how many indicators (lessons) each holds.

Built from the records already indexed in Qdrant, so it always matches what the tutor can teach.
"""

from functools import lru_cache

_SMALL_WORDS = {"and", "of", "the", "in", "to", "for", "a", "an", "on", "with", "as", "at", "or"}


def display_name(name: str) -> str:
    """The PDFs set some strand and topic names in capitals ('ORAL LANGUAGE'); show those in
    title case, leave the already-mixed-case ones ('Number: Fractions') alone."""
    name = " ".join(name.split())
    if not name.isupper():
        return name
    words = name.lower().split(" ")
    return " ".join(
        w if (i and w in _SMALL_WORDS) else w[:1].upper() + w[1:] for i, w in enumerate(words)
    )


def _position(indicator_code: str) -> tuple[int, int]:
    """(strand number, sub-strand number) from a code: B5.1.3.2.4 and SHS 1.1.1.LI.3 both carry
    them as the 2nd and 3rd dot-separated parts."""
    parts = indicator_code.split(".")
    try:
        return int(parts[1]), int(parts[2])
    except (IndexError, ValueError):
        return 10**6, 10**6


def build_topics(records: list[dict]) -> list[dict]:
    """[{name, topics: [{name, lessons}]}] ordered as the curriculum is."""
    strands: dict[tuple[int, str], dict] = {}
    for r in records:
        strand_no, sub_no = _position(r["indicator_code"])
        strand = strands.setdefault(
            (strand_no, r["strand"]), {"name": display_name(r["strand"]), "topics": {}}
        )
        topic = strand["topics"].setdefault(
            (sub_no, r["substrand"]), {"name": display_name(r["substrand"]), "lessons": 0}
        )
        topic["lessons"] += 1

    return [
        {"name": strand["name"], "topics": [t for _, t in sorted(strand["topics"].items(), key=lambda kv: kv[0])]}
        for _, strand in sorted(strands.items(), key=lambda kv: kv[0])
    ]


@lru_cache(maxsize=64)
def topics_for(grade: str, subject: str, collection: str = "curriculum") -> tuple:
    """Cached: the curriculum doesn't change while the service runs. A tuple so the cache can
    hold it; callers get a list back from `list(...)`."""
    from qdrant_client.models import FieldCondition, Filter, MatchValue

    from retrieval import get_qdrant_client

    client = get_qdrant_client()
    flt = Filter(
        must=[
            FieldCondition(key="grade", match=MatchValue(value=grade)),
            FieldCondition(key="subject", match=MatchValue(value=subject)),
        ]
    )
    records, offset = [], None
    while True:
        batch, offset = client.scroll(
            collection,
            scroll_filter=flt,
            limit=256,
            offset=offset,
            with_payload=["strand", "substrand", "indicator_code"],
            with_vectors=False,
        )
        records += [p.payload for p in batch]
        if offset is None:
            break
    return tuple(build_topics(records))
