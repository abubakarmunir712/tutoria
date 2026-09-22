"""
Provider-agnostic interface for the generation LLM.

Swapping providers (e.g. Gemini -> Claude -> GPT) means adding a new class here
and registering it in `__init__.py`'s factory — nothing else in the codebase
(retrieval, the FastAPI service, prompt construction) needs to change.
"""

from abc import ABC, abstractmethod


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
    def transcribe_image(self, image_bytes: bytes, mime_type: str) -> str:
        """Read a homework photo and return the transcribed question/problem text.
        This text is then run through the same grounded `answer()` path as a typed
        question — the vision model only reads the image, it doesn't answer from it,
        so homework photos stay grounded in the curriculum like everything else."""
        raise NotImplementedError
