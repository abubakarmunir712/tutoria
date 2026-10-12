import json
import os

from google import genai
from google.genai import types

from retrieval import WEAK_MATCH_SCORE

from pydantic import BaseModel

from .base import UNREADABLE, LlmProvider, Transcription

GRADE_NAMES = {
    "B4": "Class 4", "B5": "Class 5", "B6": "Class 6",
    "B7": "JHS 1", "B8": "JHS 2", "B9": "JHS 3",
    "SHS1": "SHS 1", "SHS2": "SHS 2", "SHS3": "SHS 3",
}
WEAK_MATCH_NOTE = (
    "Note: nothing in the curriculum matched this question closely. If it is outside this "
    "grade's curriculum (or not a school topic), say so kindly instead of forcing a match, and "
    "don't cite a code that doesn't really fit."
)


def format_context(context: list[dict]) -> str:
    """Curriculum records as the model sees them: where each sits (grade, topic, content
    standard) as well as the indicator itself, so it can tell what the lesson is about."""
    blocks = []
    for c in context:
        lines = [
            f"[{c['indicator_code']}] {GRADE_NAMES.get(c.get('grade'), c.get('grade', ''))} "
            f"{c.get('subject', '')} — {c.get('strand', '')} > {c.get('substrand', '')}"
        ]
        if c.get("content_standard_text"):
            lines.append(f"Content standard: {c['content_standard_text']}")
        lines.append(f"Indicator: {c['indicator_text']}")
        if c.get("exemplar"):
            lines.append(f"Exemplar: {c['exemplar']}")
        blocks.append("\n".join(lines))
    text = "\n\n".join(blocks)
    if context and max(c.get("score", 1.0) for c in context) < WEAK_MATCH_SCORE:
        text += f"\n\n{WEAK_MATCH_NOTE}"
    return text

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


TRANSCRIBE_PROMPT = f"""This is a phone photo of a Ghanaian school student's homework or worksheet \
(Primary, JHS or SHS). It may be tilted, shadowed, printed or handwritten.

Transcribe every question or problem exactly as written, in order, as plain text. Keep the \
question numbers and letters (1., 2., (a), (b)). Write maths the way a student would type it: \
fractions as 3/4, powers as x^2, multiplication as x, division as ÷, roots as sqrt(), keep \
decimals, units and signs exactly.

Never guess. If you cannot read a word, number or symbol, write [?] in its place instead of \
filling in something plausible. Do NOT solve, answer, explain or correct anything, and do not add \
anything that is not on the page. If the student has already written an answer or working for a question, put it on a new \
line after that question starting with "Student's working:" and copy it exactly, mistakes \
included.

Reply as JSON with three fields:
- "text": the transcription described above. If the image has no legible question or homework \
(blank, too blurry or dark to read, or not a document), use exactly: {UNREADABLE}
- "topic": a short phrase (3-8 words) naming the school topic or skill the homework tests, such as \
"adding fractions with different denominators" or "identifying nouns in sentences". Name the skill \
being practised, not the example's subject matter (for "Underline the nouns: The boy kicked the \
ball", the topic is nouns, not football). Use "" if the text is {UNREADABLE}.
- "confident": true only if every word, number and symbol of every question was clearly legible. \
false if you had to guess or skip anything (blurry, smudged, cut off, ambiguous handwriting)."""


TRANSCRIBE_AUDIO_PROMPT = (
    "This is a school child in Ghana asking a question to a tutor, in English (possibly with a "
    "Ghanaian accent). Transcribe exactly what was said, as plain text, with normal punctuation. "
    "Write numbers and maths the way a student would type them (e.g. 3/4, 2 + 5). Do not answer "
    "the question and do not add anything. If there is no intelligible speech, output nothing."
)


class _TranscriptionSchema(BaseModel):
    text: str
    topic: str
    confident: bool


class GeminiProvider(LlmProvider):
    def __init__(self, model: str | None = None):
        self._client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])
        self._model = model or os.environ.get("GEMINI_MODEL", "gemini-3.5-flash-lite")
        self._tts_model = os.environ.get("GEMINI_TTS_MODEL", "gemini-3.8-flash-lite-tts")
        self._voice = os.environ.get("GEMINI_TTS_VOICE", "Kore")

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
            context_block = format_context(context)
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

    def transcribe_image(self, image_bytes: bytes, mime_type: str) -> Transcription:
        response = self._client.models.generate_content(
            model=self._model,
            contents=[types.Part.from_bytes(data=image_bytes, mime_type=mime_type), TRANSCRIBE_PROMPT],
            config=types.GenerateContentConfig(
                temperature=0,
                response_mime_type="application/json",
                response_schema=_TranscriptionSchema,
            ),
        )
        try:
            data = json.loads(response.text)
            return Transcription(
                text=(data.get("text") or "").strip(),
                topic=(data.get("topic") or "").strip(),
                confident=bool(data.get("confident", False)),
            )
        except (ValueError, TypeError, AttributeError):
            # Model ignored the JSON format: treat whatever it said as the transcription.
            return Transcription(text=(response.text or "").strip(), confident=False)

    def transcribe_audio(self, audio_bytes: bytes, mime_type: str) -> str:
        response = self._client.models.generate_content(
            model=self._model,
            contents=[types.Part.from_bytes(data=audio_bytes, mime_type=mime_type), TRANSCRIBE_AUDIO_PROMPT],
            config=types.GenerateContentConfig(temperature=0),
        )
        return (response.text or "").strip()

    def synthesize_speech(self, text: str) -> tuple[bytes, str]:
        response = self._client.models.generate_content(
            model=self._tts_model,
            contents=f"Say this warmly and clearly, like a kind teacher talking to a child: {text}",
            config=types.GenerateContentConfig(
                response_modalities=["AUDIO"],
                speech_config=types.SpeechConfig(
                    voice_config=types.VoiceConfig(
                        prebuilt_voice_config=types.PrebuiltVoiceConfig(voice_name=self._voice)
                    )
                ),
            ),
        )
        part = response.candidates[0].content.parts[0].inline_data
        return part.data, part.mime_type or "audio/wav"
