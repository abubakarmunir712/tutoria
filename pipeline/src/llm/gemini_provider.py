import os

from google import genai
from google.genai import types

from .base import LlmProvider

SYSTEM_PROMPT = """You are Tutoria, an AI homework tutor for Ghanaian students, grounded in the \
official NaCCA curriculum. You MUST answer only using the curriculum context provided below \
— it is retrieved from the official indicator for the student's grade and subject. Do not \
introduce outside methods or content beyond what's in the context. Explain simply, the way a \
patient teacher would to a child at this grade level. When helpful, reference the indicator \
code so the student/teacher can trace the answer back to the curriculum standard.

If the retrieved context doesn't actually cover the student's question, say so plainly instead \
of guessing — do not fabricate curriculum content.

Formatting rules (this renders in a mobile chat bubble, not a document):
- Use simple Markdown only: **bold**, and numbered/bulleted lists where they genuinely help.
- NEVER use LaTeX or math markup (no $...$, no \\frac{}{}, no \\times, etc). Write fractions, \
  equations, and symbols as plain text a student would write by hand, e.g. "1/2", "3 x 4 = 12", \
  "<", ">", "cm²".
- Keep paragraphs short. Avoid deep nesting or headers."""


class GeminiProvider(LlmProvider):
    def __init__(self, model: str | None = None):
        self._client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])
        self._model = model or os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")

    def answer(self, question: str, context: list[dict]) -> str:
        context_block = "\n\n".join(
            f"[{c['indicator_code']}] {c['indicator_text']}\nExemplar: {c.get('exemplar', '')}"
            for c in context
        )
        prompt = f"Curriculum context:\n{context_block}\n\nStudent question: {question}"

        response = self._client.models.generate_content(
            model=self._model,
            contents=prompt,
            config=types.GenerateContentConfig(system_instruction=SYSTEM_PROMPT),
        )
        return response.text

    def transcribe_image(self, image_bytes: bytes, mime_type: str) -> str:
        response = self._client.models.generate_content(
            model=self._model,
            contents=[
                types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                "This is a photo of a Ghanaian primary school student's homework. "
                "Transcribe the exact question/problem being asked, as plain text. "
                "Do not answer it or solve it — only transcribe the question.",
            ],
        )
        return response.text
