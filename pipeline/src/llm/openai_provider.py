import base64
import io
import json
import os
import wave

from openai import OpenAI

from .base import LlmProvider, Transcription
from .prompts import SYSTEM_PROMPT, TRANSCRIBE_AUDIO_PROMPT, TRANSCRIBE_PROMPT, format_context

# Style for the spoken reply. gpt-4o-mini-tts takes this as a separate field, so (unlike Gemini
# TTS) it is never read aloud.
TTS_INSTRUCTIONS = (
    "Speak as a warm, patient, encouraging tutor talking to a school child. Clear, friendly and "
    "unhurried, with a natural Ghanaian-English-friendly pace."
)


class OpenAIProvider(LlmProvider):
    def __init__(self, model: str | None = None):
        # The repo's .env names the key OPEN_API_KEY; OPENAI_API_KEY is the SDK's own name.
        key = os.environ.get("OPENAI_API_KEY") or os.environ["OPEN_API_KEY"]
        self._client = OpenAI(api_key=key)
        self._model = model or os.environ.get("OPENAI_MODEL", "gpt-4.1-mini")
        self._stt_model = os.environ.get("OPENAI_STT_MODEL", "gpt-4o-mini-transcribe")
        self._tts_model = os.environ.get("OPENAI_TTS_MODEL", "gpt-4o-mini-tts")
        self._voice = os.environ.get("OPENAI_TTS_VOICE", "coral")

    def answer(
        self,
        question: str,
        context: list[dict],
        history: list[dict] | None = None,
    ) -> str:
        messages = [{"role": "system", "content": SYSTEM_PROMPT}]
        messages += [
            {"role": "assistant" if t.get("role") == "assistant" else "user", "content": t["content"]}
            for t in (history or [])
            if t.get("content")
        ]
        if context:
            user_text = f"Curriculum context:\n{format_context(context)}\n\nStudent: {question}"
        else:
            user_text = question
        messages.append({"role": "user", "content": user_text})

        response = self._client.chat.completions.create(model=self._model, messages=messages)
        return response.choices[0].message.content or ""

    def transcribe_image(self, image_bytes: bytes, mime_type: str) -> Transcription:
        data_url = f"data:{mime_type};base64,{base64.b64encode(image_bytes).decode()}"
        response = self._client.chat.completions.create(
            model=self._model,
            temperature=0,
            response_format={"type": "json_object"},
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "image_url", "image_url": {"url": data_url}},
                        {"type": "text", "text": TRANSCRIBE_PROMPT},
                    ],
                }
            ],
        )
        raw = response.choices[0].message.content or ""
        try:
            data = json.loads(raw)
            return Transcription(
                text=(data.get("text") or "").strip(),
                topic=(data.get("topic") or "").strip(),
                confident=bool(data.get("confident", False)),
            )
        except (ValueError, TypeError, AttributeError):
            return Transcription(text=raw.strip(), confident=False)

    def transcribe_audio(self, audio_bytes: bytes, mime_type: str) -> str:
        ext = {"audio/mp4": "m4a", "audio/aac": "aac", "audio/mpeg": "mp3", "audio/wav": "wav",
               "audio/x-wav": "wav", "audio/webm": "webm", "audio/ogg": "ogg"}.get(mime_type, "m4a")
        result = self._client.audio.transcriptions.create(
            model=self._stt_model,
            file=(f"question.{ext}", audio_bytes, mime_type),
            language="en",
            prompt=TRANSCRIBE_AUDIO_PROMPT,
            temperature=0,
        )
        return (result.text or "").strip()

    def synthesize_speech(self, text: str) -> tuple[bytes, str]:
        response = self._client.audio.speech.create(
            model=self._tts_model,
            voice=self._voice,
            input=text,
            instructions=TTS_INSTRUCTIONS,
            # Raw 24 kHz 16-bit mono PCM, wrapped below. OpenAI's own "wav" output carries a
            # streaming header with the length unset, which Android's player refuses to open.
            response_format="pcm",
        )
        buf = io.BytesIO()
        with wave.open(buf, "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(24000)
            wav.writeframes(response.content)
        return buf.getvalue(), "audio/wav"
