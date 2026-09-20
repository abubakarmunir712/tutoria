"""
AI service: the internal HTTP API the NestJS server proxies chat/OCR requests to.

Run: uvicorn service:app --reload --port 8000  (from pipeline/src/)
"""

from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI, File, Form, HTTPException, UploadFile  # noqa: E402
from fastapi.staticfiles import StaticFiles  # noqa: E402
from pydantic import BaseModel  # noqa: E402

from llm import get_llm_provider  # noqa: E402
from retrieval import retrieve  # noqa: E402

app = FastAPI(title="Tutoria AI Service")

IMAGES_DIR = Path(__file__).resolve().parent.parent / "data" / "structured" / "images"
IMAGES_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/images", StaticFiles(directory=IMAGES_DIR), name="images")


class AskRequest(BaseModel):
    question: str
    grade: str | None = None
    subject: str | None = None
    top_k: int = 3


class AskResponse(BaseModel):
    answer: str
    citations: list[dict]


def _answer_grounded(question: str, grade: str | None, subject: str | None, top_k: int) -> AskResponse:
    context = retrieve(question, grade, subject, top_k=top_k)
    if not context:
        return AskResponse(
            answer="I couldn't find anything in the curriculum for this grade/subject that matches "
            "your question. Try rephrasing, or check the grade/subject selected.",
            citations=[],
        )
    llm = get_llm_provider()
    answer_text = llm.answer(question, context)
    citations = [
        {
            "indicator_code": c["indicator_code"],
            "strand": c["strand"],
            "substrand": c["substrand"],
            "images": c.get("images", []),
        }
        for c in context
    ]
    return AskResponse(answer=answer_text, citations=citations)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/ask", response_model=AskResponse)
def ask(req: AskRequest):
    return _answer_grounded(req.question, req.grade, req.subject, req.top_k)


@app.post("/ask-image", response_model=AskResponse)
async def ask_image(
    image: UploadFile = File(...),
    grade: str | None = Form(None),
    subject: str | None = Form(None),
    top_k: int = Form(3),
):
    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(400, "Empty image upload")

    llm = get_llm_provider()
    transcribed_question = llm.transcribe_image(image_bytes, image.content_type or "image/jpeg")
    result = _answer_grounded(transcribed_question, grade, subject, top_k)
    result.answer = f"(Read from your photo: “{transcribed_question.strip()}”)\n\n{result.answer}"
    return result
