import json
import os

from google import genai
from google.genai import types

from pydantic import BaseModel

from .base import LlmProvider, Transcription
from .prompts import SYSTEM_PROMPT, TRANSCRIBE_AUDIO_PROMPT, TRANSCRIBE_PROMPT, format_context


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
            # Only the words to speak. A style instruction in the text ("say this warmly...") gets
            # read aloud by the model, and this model refuses a separate system instruction.
            contents=text,
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
