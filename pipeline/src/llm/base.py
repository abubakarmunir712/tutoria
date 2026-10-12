"""
Provider-agnostic interface for the generation LLM.

Swapping providers (e.g. Gemini -> Claude -> GPT) means adding a new class here
and registering it in `__init__.py`'s factory — nothing else in the codebase
(retrieval, the FastAPI service, prompt construction) needs to change.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass

# Returned by transcribe_image when the photo has no legible question (blank, too blurry, not
# homework). The service turns this into a "please retake the photo" reply instead of letting
# the model invent a question.
UNREADABLE = "UNREADABLE"


@dataclass
class Transcription:
    text: str  # the question(s) as plain text, or UNREADABLE
    topic: str = ""  # a few words naming the school topic/skill the homework tests
    confident: bool = True  # False if the model had to guess any word, number or symbol

    @property
    def unreadable(self) -> bool:
        return not self.text.strip() or self.text.strip().upper().startswith(UNREADABLE)

    @property
    def needs_confirmation(self) -> bool:
        """Readable, but not reliably: tutoring a misread problem is worse than asking."""
        return not self.unreadable and (not self.confident or "[?]" in self.text)


class LlmProvider(ABC):
    @abstractmethod
    def answer(
        self,
        question: str,
        context: list[dict],
        history: list[dict] | None = None,
    ) -> str:
        """Generate a grounded tutor answer from the student's question + retrieved
        curriculum records (each with indicator_code, indicator_text, exemplar, etc.).
        `history` is prior turns in this conversation, as [{role: 'user'|'assistant',
        content: str}] — pass through for multi-turn/Socratic follow-ups; `context` is
        typically empty on those turns (only the first message in a topic re-grounds)."""
        raise NotImplementedError

    @abstractmethod
    def transcribe_image(self, image_bytes: bytes, mime_type: str) -> Transcription:
        """Read a homework photo and return the transcribed question(s) as plain text, or
        UNREADABLE if there is no legible question, plus a short topic phrase for the search. If the student has already written an
        answer or working, it follows the question on a line starting "Student's working:".
        This text is then run through the same grounded `answer()` path as a typed
        question — the vision model only reads the image, it doesn't answer from it,
        so homework photos stay grounded in the curriculum like everything else."""
        raise NotImplementedError

    @abstractmethod
    def transcribe_audio(self, audio_bytes: bytes, mime_type: str) -> str:
        """Speech-to-text for a student's spoken question (English). Returns just the words
        spoken, or "" if there is no intelligible speech. The text then goes through the same
        grounded `answer()` path as a typed question."""
        raise NotImplementedError

    @abstractmethod
    def synthesize_speech(self, text: str) -> tuple[bytes, str]:
        """Text-to-speech for a tutor reply (English). Returns (audio bytes, mime type)."""
        raise NotImplementedError
