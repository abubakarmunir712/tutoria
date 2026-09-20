import os
from functools import lru_cache

from .base import LlmProvider


@lru_cache
def get_llm_provider() -> LlmProvider:
    provider = os.environ.get("LLM_PROVIDER", "gemini").lower()
    if provider == "gemini":
        from .gemini_provider import GeminiProvider

        return GeminiProvider()
    raise ValueError(f"Unknown LLM_PROVIDER: {provider}")
