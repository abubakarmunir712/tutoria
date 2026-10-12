"""
AI service: the internal HTTP API the NestJS server proxies chat/OCR requests to.

Run: uvicorn service:app --reload --port 8000  (from pipeline/src/)
"""

import json
import logging
import re
import time
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI, File, Form, HTTPException, Response, UploadFile  # noqa: E402
from fastapi.staticfiles import StaticFiles  # noqa: E402
from pydantic import BaseModel  # noqa: E402

from llm import get_llm_provider  # noqa: E402
from speech import speakable_text  # noqa: E402
from topics import topics_for  # noqa: E402
from retrieval import (  # noqa: E402
    WEAK_MATCH_SCORE,
    build_retrieval_query,
    correct_spelling,
    curriculum_vocabulary,
    expand_student_terms,
    retrieve,
)

app = FastAPI(title="Tutoria AI Service")
log = logging.getLogger("uvicorn.error")

IMAGES_DIR = Path(__file__).resolve().parent.parent / "data" / "structured" / "images"
IMAGES_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/images", StaticFiles(directory=IMAGES_DIR), name="images")


class HistoryTurn(BaseModel):
    role: str  # 'user' | 'assistant'
    content: str


class AskRequest(BaseModel):
    question: str
    grade: str | None = None
    subject: str | None = None
    top_k: int = 3
    history: list[HistoryTurn] = []


class AskResponse(BaseModel):
    answer: str
    citations: list[dict]


def _answer_grounded(
    question: str,
    grade: str | None,
    subject: str | None,
    top_k: int,
    history: list[HistoryTurn] | None = None,
    search_text: str | None = None,
) -> AskResponse:
    """`search_text` is what to look up in the curriculum when it differs from the message the
    model sees (a photo: the model gets the whole transcription, the search gets just the
    questions)."""
    history = history or []
    history_dicts = [h.model_dump() for h in history]

    # Re-ground every turn. A reply that carries no topic of its own ("yes", "5", "why is that?")
    # is searched together with the student's last real question, so a Socratic back-and-forth
    # keeps the same curriculum context; a message that states a new topic gets its own.
    search_query = expand_student_terms(
        correct_spelling(build_retrieval_query(search_text or question, history_dicts), curriculum_vocabulary())
    )
    context = retrieve(search_query, grade, subject, top_k=top_k)
    if not context and not history:
        return AskResponse(
            answer="I couldn't find anything in the curriculum for this grade/subject that "
            "matches your question. Try rephrasing, or check the grade/subject selected.",
            citations=[],
        )

    llm = get_llm_provider()
    answer_text = llm.answer(question, context, history=history_dicts)
    # A weak best match means nothing really fits (the model was told so); don't show the
    # student curriculum citations and diagrams for a question the curriculum doesn't cover.
    weak = not context or max(c["score"] for c in context) < WEAK_MATCH_SCORE
    citations = (
        []
        if weak
        else [
            {
                "indicator_code": c["indicator_code"],
                "strand": c["strand"],
                "substrand": c["substrand"],
                "images": c.get("images", []),
            }
            for c in context
        ]
    )
    return AskResponse(answer=answer_text, citations=citations)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/topics")
def topics(grade: str, subject: str):
    """The curriculum's strands and topics for a grade and subject, in curriculum order."""
    strands = list(topics_for(grade, subject))
    if not strands:
        raise HTTPException(404, "No curriculum topics for this grade and subject")
    return {"grade": grade, "subject": subject, "strands": strands}


@app.post("/ask", response_model=AskResponse)
def ask(req: AskRequest):
    return _answer_grounded(req.question, req.grade, req.subject, req.top_k, req.history)


MAX_IMAGE_BYTES = 10 * 1024 * 1024
UNREADABLE_PHOTO_REPLY = (
    "I couldn't read a question in that photo. Try again in good light, hold the camera "
    "straight above the page, and make sure the whole question is in the picture."
)
CONFIRM_PHOTO_REPLY = (
    "I'm not 100% sure I read that right. Reply **yes** if it's correct, or type what it "
    "should say. You can also take the photo again."
)
_WORKING_RE = re.compile(r"^\s*student'?s working\s*:", re.IGNORECASE)
_QUESTION_START_RE = re.compile(r"^\s*(?:q(?:uestion)?\s*)?\(?\d+[.):]|^\s*\([a-z]\)", re.IGNORECASE)


def strip_student_working(text: str) -> str:
    """The questions on their own: drop each 'Student's working:' block (up to the next
    question), so a student's wrong attempt doesn't steer the curriculum search."""
    kept, skipping = [], False
    for line in text.splitlines():
        if _WORKING_RE.match(line):
            skipping = True
            continue
        if skipping and _QUESTION_START_RE.match(line):
            skipping = False
        if not skipping:
            kept.append(line)
    return "\n".join(kept).strip()


_NUMBERED_RE = re.compile(r"^\s*(?:q(?:uestion)?\s*)?\d+[.):]", re.IGNORECASE)


def count_questions(text: str) -> int:
    """Numbered questions only — '(a)', '(b)' are parts of one question."""
    return sum(1 for line in text.splitlines() if _NUMBERED_RE.match(line))


def quote_photo_text(transcription: str, heading: str = "Read from your photo:") -> str:
    quoted = "\n".join(f"> {line}" if line.strip() else ">" for line in transcription.splitlines())
    return f"> **{heading}**\n{quoted}"


def first_question_block(questions: str) -> str:
    """Everything up to (not including) the second numbered question: the sheet's heading or
    instruction plus question 1 (with its (a)/(b) parts)."""
    kept, numbered = [], 0
    for line in questions.splitlines():
        if _NUMBERED_RE.match(line):
            numbered += 1
            if numbered > 1:
                break
        kept.append(line)
    return "\n".join(kept).strip()


def photo_search_text(topic: str, questions: str) -> str:
    """What to look up in the curriculum for a photo.

    One question: the topic phrase the vision model wrote leads, because a worksheet's
    instruction ("Underline the nouns") names the skill while its example sentence ("The boy
    kicked the ball") is just content that would pull the search off-topic.
    Several questions: the tutor works through them one at a time starting with the first, so
    search on the heading and question 1 — a topic for the whole sheet, or all five questions
    at once, would blend fractions and perimeter into a match for neither.
    """
    if count_questions(questions) > 1:
        return first_question_block(questions)
    return f"{topic}. {questions}" if topic else questions


def photo_message(transcription: str) -> str:
    """What the model is told when a student sends a homework photo."""
    note = ""
    if count_questions(strip_student_working(transcription)) > 1:
        note = (
            "\n\nThere are several questions. Don't answer them all: say in one short line "
            "that you can see them, then start tutoring the FIRST one, step by step."
        )
    return f"I sent a photo of my homework. It says:\n{transcription}{note}"


def parse_history(raw: str | None) -> list[HistoryTurn]:
    """History arrives as a JSON string in the multipart form; a bad value just means none."""
    if not raw:
        return []
    try:
        return [HistoryTurn(**turn) for turn in json.loads(raw)][-10:]
    except (ValueError, TypeError):
        return []


@app.post("/ask-image", response_model=AskResponse)
async def ask_image(
    image: UploadFile = File(...),
    grade: str | None = Form(None),
    subject: str | None = Form(None),
    top_k: int = Form(3),
    history: str | None = Form(None),
):
    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(400, "Empty image upload")
    if len(image_bytes) > MAX_IMAGE_BYTES:
        raise HTTPException(413, "Image is too large (max 10 MB)")

    content_type = image.content_type if (image.content_type or "").startswith("image/") else "image/jpeg"
    llm = get_llm_provider()
    scan = llm.transcribe_image(image_bytes, content_type)
    if scan.unreadable:
        return AskResponse(answer=UNREADABLE_PHOTO_REPLY, citations=[])

    transcription = scan.text
    if scan.needs_confirmation:
        # Don't tutor a problem the model may have misread; show what it saw and let the
        # student confirm. Their next message ("yes") is grounded on this quoted text.
        return AskResponse(answer=f"{quote_photo_text(transcription, 'Is this what your homework says?')}\n\n{CONFIRM_PHOTO_REPLY}", citations=[])

    questions_only = strip_student_working(transcription) or transcription
    result = _answer_grounded(
        photo_message(transcription),
        grade,
        subject,
        top_k,
        parse_history(history),
        search_text=photo_search_text(scan.topic, questions_only),
    )
    result.answer = f"{quote_photo_text(transcription)}\n\n{result.answer}"
    return result


MAX_AUDIO_BYTES = 10 * 1024 * 1024


class SpeakRequest(BaseModel):
    text: str


@app.post("/transcribe-audio")
async def transcribe_audio(audio: UploadFile = File(...)):
    """A student's spoken question -> text. The app shows the text and sends it through /ask,
    so a voice question is grounded exactly like a typed one."""
    audio_bytes = await audio.read()
    if not audio_bytes:
        raise HTTPException(400, "Empty audio upload")
    if len(audio_bytes) > MAX_AUDIO_BYTES:
        raise HTTPException(413, "Audio is too large (max 10 MB)")
    content_type = audio.content_type if (audio.content_type or "").startswith("audio/") else "audio/mp4"
    started = time.perf_counter()
    text = get_llm_provider().transcribe_audio(audio_bytes, content_type)
    log.info("stt bytes=%d seconds=%.2f chars=%d", len(audio_bytes), time.perf_counter() - started, len(text))
    return {"text": text}


@app.post("/speak")
def speak(req: SpeakRequest):
    """A tutor reply -> spoken audio (what the child hears), with citation codes and markdown removed."""
    spoken = speakable_text(req.text)
    if not spoken:
        raise HTTPException(400, "Nothing to say")
    started = time.perf_counter()
    audio, mime = get_llm_provider().synthesize_speech(spoken)
    log.info("tts chars=%d seconds=%.2f bytes=%d", len(spoken), time.perf_counter() - started, len(audio))
    return Response(content=audio, media_type=mime)
