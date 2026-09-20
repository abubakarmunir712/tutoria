"""
Terminal RAG test: student question -> filtered retrieval (grade/subject) -> context.

Run: python src/query_rag.py "How do I compare two 5-digit numbers?" --grade B4 --subject Mathematics
"""

import argparse

from dotenv import load_dotenv

load_dotenv()

from retrieval import retrieve  # noqa: E402


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("question")
    parser.add_argument("--grade")
    parser.add_argument("--subject")
    parser.add_argument("--collection", default="curriculum")
    parser.add_argument("--top-k", type=int, default=3)
    args = parser.parse_args()

    results = retrieve(args.question, args.grade, args.subject, args.collection, args.top_k)

    print(f"Question: {args.question}\n")
    if not results:
        print("No matches found.")
        return

    for i, p in enumerate(results, 1):
        print(f"--- Match {i} (score={p['score']:.3f}) ---")
        print(f"{p['grade']} {p['subject']} | {p['strand']} > {p['substrand']}")
        print(f"Indicator {p['indicator_code']}: {p['indicator_text']}")
        if p.get("exemplar"):
            print(f"Exemplar: {p['exemplar'][:300]}")
        if p.get("images"):
            print(f"Images: {', '.join(p['images'])}")
        print()


if __name__ == "__main__":
    main()
