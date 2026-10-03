"""
Offline retrieval evaluation — no Qdrant needed. Embeds the structured records locally under
different strategies and scores them against eval/queries.py.

Run (from pipeline/):  python eval/run_eval.py [--variants v0 v1 ...] [--records-dir DIR] [-v]

Strategies are defined in VARIANTS below; add one to compare it.
"""

import argparse
import glob
import hashlib
import json
import os
import re
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "src"))
sys.path.insert(0, str(ROOT / "eval"))

from queries import CASES  # noqa: E402

CACHE = Path(os.environ.get("EVAL_CACHE", "/tmp/eval_cache"))
CACHE.mkdir(parents=True, exist_ok=True)
FASTEMBED_DIR = os.environ.get("FASTEMBED_CACHE_DIR", "/tmp/fe_cache")
BGE_QUERY_PREFIX = "Represent this sentence for searching relevant passages: "

GRADE_LABEL = {
    "B4": "Primary 4", "B5": "Primary 5", "B6": "Primary 6",
    "B7": "JHS 1", "B8": "JHS 2", "B9": "JHS 3",
    "SHS1": "SHS 1", "SHS2": "SHS 2", "SHS3": "SHS 3",
}


def load_records(directory: Path):
    records = []
    for f in sorted(glob.glob(str(directory / "*.json"))):
        records += json.load(open(f))
    return records


# ---- document text strategies -------------------------------------------------------------

def text_plain(r):  # what is embedded today
    return f"{r['indicator_text']} {r['exemplar']}".strip()


def text_context(r):
    """Indicator plus where it sits in the curriculum, so 'parts of a computer' can match a
    sub-strand/content standard about computer components even when the indicator is terse."""
    parts = [
        f"{r['subject']} {GRADE_LABEL.get(r['grade'], r['grade'])}.",
        f"Topic: {r['strand']} - {r['substrand']}.",
    ]
    if r["content_standard_text"]:
        parts.append(f"Standard: {r['content_standard_text']}")
    parts.append(f"Indicator: {r['indicator_text']}")
    if r["exemplar"]:
        parts.append(f"Examples: {r['exemplar']}")
    return " ".join(parts)


def text_context_short(r):
    """Like context but exemplars capped, so a long exemplar doesn't drown the topic signal."""
    parts = [f"{r['subject']}. {r['strand']} - {r['substrand']}."]
    if r["content_standard_text"]:
        parts.append(r["content_standard_text"])
    parts.append(r["indicator_text"])
    if r["exemplar"]:
        parts.append(r["exemplar"][:300])
    return " ".join(parts)


# name -> (doc text fn, embedding model, query prefix)
VARIANTS = {
    "v0": (text_plain, "BAAI/bge-small-en-v1.5", ""),
    "v1": (text_context, "BAAI/bge-small-en-v1.5", ""),
    "v2": (text_context_short, "BAAI/bge-small-en-v1.5", ""),
    "v3": (text_context_short, "BAAI/bge-small-en-v1.5", BGE_QUERY_PREFIX),
    "v4": (text_context_short, "BAAI/bge-base-en-v1.5", BGE_QUERY_PREFIX),
}


# ---- embedding with on-disk cache ---------------------------------------------------------

_embedders = {}


def embedder(model):
    from fastembed import TextEmbedding

    if model not in _embedders:
        _embedders[model] = TextEmbedding(model_name=model, cache_dir=FASTEMBED_DIR)
    return _embedders[model]


def embed(texts, model, tag):
    key = hashlib.md5((model + tag + "".join(texts)).encode()).hexdigest()[:16]
    path = CACHE / f"{key}.npy"
    if path.exists():
        return np.load(path)
    vecs = np.array(list(embedder(model).embed(texts, batch_size=32)), dtype=np.float32)
    vecs /= np.linalg.norm(vecs, axis=1, keepdims=True)
    np.save(path, vecs)
    return vecs


# ---- BM25 (for hybrid) --------------------------------------------------------------------

STOP = set("a an the of to in is are and or for on with how do does what i it my we you be as at by from this that".split())


def stem(w):
    for suf, rep in (("ies", "y"), ("ing", ""), ("es", ""), ("s", ""), ("ed", "")):
        if w.endswith(suf) and len(w) - len(suf) >= 3:
            return w[: -len(suf)] + rep
    return w


def tokens(text):
    return [stem(w) for w in re.findall(r"[a-z0-9]+", text.lower()) if w not in STOP]


class BM25:
    def __init__(self, docs, k1=1.4, b=0.75):
        self.k1, self.b = k1, b
        self.docs = [tokens(d) for d in docs]
        self.avg = sum(map(len, self.docs)) / len(self.docs)
        df = {}
        for d in self.docs:
            for t in set(d):
                df[t] = df.get(t, 0) + 1
        n = len(self.docs)
        self.idf = {t: np.log(1 + (n - c + 0.5) / (c + 0.5)) for t, c in df.items()}
        self.tf = [{t: d.count(t) for t in set(d)} for d in self.docs]

    def scores(self, query):
        q = tokens(query)
        out = np.zeros(len(self.docs), dtype=np.float32)
        for i, (tf, d) in enumerate(zip(self.tf, self.docs)):
            norm = self.k1 * (1 - self.b + self.b * len(d) / self.avg)
            out[i] = sum(self.idf.get(t, 0) * tf[t] * (self.k1 + 1) / (tf[t] + norm) for t in q if t in tf)
        return out


# ---- evaluation ---------------------------------------------------------------------------

def rrf(rank_lists, k=60):
    score = {}
    for ranks in rank_lists:
        for pos, idx in enumerate(ranks):
            score[idx] = score.get(idx, 0) + 1 / (k + pos + 1)
    return sorted(score, key=score.get, reverse=True)


def evaluate(records, name, dense_fn, rank_fn, verbose):
    ks = (1, 3, 5)
    hits = {k: 0 for k in ks}
    mrr = 0.0
    n = 0
    uncovered = []
    misses = []
    by_phase = {}
    for q, grade, subject, rel in CASES:
        pool = [i for i, r in enumerate(records) if r["grade"] == grade and r["subject"] == subject]
        pat = re.compile(rel, re.I)
        relevant = {i for i in pool if pat.search(
            f"{records[i]['indicator_text']} {records[i]['content_standard_text']} {records[i]['substrand']}")}
        if not relevant:
            uncovered.append((q, grade, subject))
            continue
        ranked = rank_fn(q, pool)
        n += 1
        first = next((p for p, i in enumerate(ranked) if i in relevant), None)
        for k in ks:
            hits[k] += first is not None and first < k
        mrr += 1 / (first + 1) if first is not None else 0
        phase = "SHS" if grade.startswith("SHS") else ("JHS" if grade in ("B7", "B8", "B9") else "UP")
        by_phase.setdefault(phase, [0, 0])
        by_phase[phase][1] += 1
        by_phase[phase][0] += first is not None and first < 3
        if first is None or first >= 3:
            misses.append((q, grade, subject, first, [records[i]["indicator_code"] for i in ranked[:3]]))
    print(f"\n=== {name}: n={n}  R@1={hits[1]/n:.2f}  R@3={hits[3]/n:.2f}  R@5={hits[5]/n:.2f}  MRR={mrr/n:.3f}"
          f"   (R@3 by phase: " + ", ".join(f"{p} {a}/{t}" for p, (a, t) in sorted(by_phase.items())) + ")")
    if verbose:
        for q, g, s, first, top in misses:
            print(f"   MISS@3 [{g} {s}] {q!r} first_rel={first} top3={top}")
        if uncovered:
            print("   not covered:", [(q, g) for q, g, _ in uncovered])
    return hits[3] / n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--variants", nargs="*", default=list(VARIANTS))
    ap.add_argument("--records-dir", default=str(ROOT / "data" / "structured"))
    ap.add_argument("--hybrid", action="store_true", help="also report dense+BM25 reciprocal-rank-fusion")
    ap.add_argument("--rerank", default=None, help="cross-encoder model to rerank the top candidates with")
    ap.add_argument("--rerank-n", type=int, default=15)
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()

    records = load_records(Path(args.records_dir))
    print(f"{len(records)} records, {len(CASES)} queries")

    for name in args.variants:
        text_fn, model, qprefix = VARIANTS[name]
        texts = [text_fn(r) for r in records]
        doc_vecs = embed(texts, model, name)
        qvecs = {}

        def dense_rank(q, pool, doc_vecs=doc_vecs, model=model, qprefix=qprefix, qvecs=qvecs):
            if q not in qvecs:
                v = np.array(next(embedder(model).embed([qprefix + q])), dtype=np.float32)
                qvecs[q] = v / np.linalg.norm(v)
            sims = doc_vecs[pool] @ qvecs[q]
            return [pool[i] for i in np.argsort(-sims)]

        evaluate(records, f"{name} dense ({model.split('/')[-1]}, {text_fn.__name__})", None, dense_rank, args.verbose)

        if args.hybrid:
            bm = BM25(texts)

            def hybrid_rank(q, pool, bm=bm, dense_rank=dense_rank):
                d = dense_rank(q, pool)
                s = bm.scores(q)
                lex = sorted(pool, key=lambda i: -s[i])
                return rrf([d, lex])

            evaluate(records, f"{name} hybrid dense+BM25", None, hybrid_rank, args.verbose)

        if args.rerank:
            from fastembed.rerank.cross_encoder import TextCrossEncoder

            ce = TextCrossEncoder(model_name=args.rerank, cache_dir=FASTEMBED_DIR)
            ce_cache = {}

            def rerank_of(first_stage, texts=texts):
                def rank(q, pool):
                    cand = first_stage(q, pool)[: args.rerank_n]
                    key = (q, tuple(cand))
                    if key not in ce_cache:
                        ce_cache[key] = list(ce.rerank(q, [texts[i] for i in cand]))
                    return [i for _, i in sorted(zip(ce_cache[key], cand), key=lambda t: -t[0])] + first_stage(q, pool)[args.rerank_n:]
                return rank

            evaluate(records, f"{name} dense -> rerank({args.rerank.split('/')[-1]})", None, rerank_of(dense_rank), args.verbose)
            if args.hybrid:
                evaluate(records, f"{name} hybrid -> rerank({args.rerank.split('/')[-1]})", None, rerank_of(hybrid_rank), args.verbose)


if __name__ == "__main__":
    main()
