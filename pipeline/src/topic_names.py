"""
Topic names the extractor could not read from the PDFs.

Some NaCCA sub-strands have no header of their own (B5 Mathematics' decimals and percentages sit
under the "Fractions" header), and a few repeat a neighbour's name. name_topics.py asks the model
for a proper short title once for each such group and stores it in data/topic_names.json, keyed
"<source slug>|<grade>.<strand>.<sub-strand>|<name the extractor gave it>", e.g.
"mathematics-upper-primary|B5.1.4|Decimals fractions and strategies for comparing". The current name
is part of the key because the PDFs sometimes reuse one code group for several differently titled
sections: only the section that was ambiguous is renamed, the properly headed ones keep their names.
This module reapplies those names on every extraction, so they survive re-running the pipeline.
"""

import json
from pathlib import Path

NAMES_PATH = Path(__file__).resolve().parent.parent / "data" / "topic_names.json"


def load_names() -> dict[str, str]:
    return json.loads(NAMES_PATH.read_text()) if NAMES_PATH.exists() else {}


def group_key(slug: str, indicator_code: str, current_name: str) -> str:
    return f"{slug}|{'.'.join(indicator_code.split('.')[:3])}|{current_name}"


def apply_topic_names(slug: str, records: list[dict]) -> int:
    """Set `substrand` from the stored names; returns how many records changed."""
    names = load_names()
    changed = 0
    for r in records:
        name = names.get(group_key(slug, r["indicator_code"], r["substrand"]))
        if name and (r["substrand"] != name or r.get("substrand_inferred")):
            r["substrand"], r["substrand_inferred"] = name, False
            changed += 1
    return changed
