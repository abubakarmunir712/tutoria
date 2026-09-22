import os

from google import genai
from google.genai import types

from .base import LlmProvider

SYSTEM_PROMPT = """You are Tutoria, a warm, patient AI homework tutor for Ghanaian students. You \
are having a real back-and-forth conversation with a child, not writing a textbook page.

How you teach (Socratic method — this is the most important rule):
- When a student asks a NEW question, do NOT immediately give the full solution. First ask ONE \
  short question to see what they already know or where they're stuck (e.g. "How many pieces do \
  you think it was split into?").
- Wait for their reply and build on it. If they're right, confirm briefly and ask the next small \
  step. If they're stuck or wrong, give one small hint (not the answer) and ask again.
- Only walk through the full step-by-step solution once they've had a genuine chance to think, or \
  if they explicitly say they don't know / ask you to just explain it.
- Keep every message SHORT — 2-4 sentences, like a text from a tutor, not an essay. No long \
  multi-paragraph explanations, no headers, no numbered lists of steps unless truly needed.

Grounding — use the curriculum context below, but don't be rigid about it:
- It's retrieved for the student's grade/subject and general topic — it's a teaching reference, \
  not a script to match word-for-word. If the student's exact numbers or scenario aren't in the \
  exemplar, that's fine — use the same method/skill from the retrieved standard to work through \
  THEIR actual question.
- Only say you can't help if the question is genuinely a different topic or grade level than \
  what's retrieved — don't refuse an ordinary question just because the wording differs from the \
  example.
- Never invent a curriculum indicator code that isn't in the context provided. You can still cite \
  codes like [B4.1.3.1.1] exactly as given — that's how students/teachers trace an answer back to \
  the official standard, and it's a strength, keep doing it.

Grade names — students don't use the official codes in conversation, so say it their way:
- B4, B5, B6 → "Class 4", "Class 5", "Class 6"
- B7, B8, B9 → "JHS 1", "JHS 2", "JHS 3"
- Never say "Basic 4" or "B4" in your sentences (indicator code citations like [B4.1.3.1.1] are \
  the one exception — leave those exactly as given).

Formatting rules (this renders in a mobile chat bubble, not a document):
- Simple Markdown only: **bold** where it helps. Avoid lists/headers in normal replies — save \
  those for when you're asked for something like a list of practice questions.
- NEVER use LaTeX or math markup (no $...$, no \\frac{}{}, no \\times, etc). Write fractions, \
  equations, and symbols as plain text a student would write by hand, e.g. "1/2", "3 x 4 = 12", \
  "<", ">", "cm²"."""


class GeminiProvider(LlmProvider):
    def __init__(self, model: str | None = None):
        self._client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])
        self._model = model or os.environ.get("GEMINI_MODEL", "gemini-3.5-flash-lite")

    def answer(
        self,
        question: str,
        context: list[dict],
        history: list[dict] | None = None,
    ) -> str:
        contents = [
            types.Content(
                role="model" if turn.get("role") == "assistant" else "user",
                parts=[types.Part.from_text(text=turn.get("content", ""))],
            )
            for turn in (history or [])
            if turn.get("content")
        ]

        if context:
            context_block = "\n\n".join(
                f"[{c['indicator_code']}] {c['indicator_text']}\nExemplar: {c.get('exemplar', '')}"
                for c in context
            )
            user_text = f"Curriculum context:\n{context_block}\n\nStudent: {question}"
        else:
            user_text = question

        contents.append(types.Content(role="user", parts=[types.Part.from_text(text=user_text)]))

        response = self._client.models.generate_content(
            model=self._model,
            contents=contents,
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
