"""
Generate synthetic homework-photo test images with known ground truth.

These are STAND-INS for real worksheet photos: printed or handwriting-styled text on paper,
degraded the way phone photos are (tilt, perspective, uneven light, noise, blur, JPEG
compression). They give the OCR evaluation a known right answer to score against. Real photos
(put them in eval/ocr/real/) are the true test — see run_ocr_eval.py.

Run (from pipeline/):  python eval/ocr/make_worksheets.py
Writes eval/ocr/worksheets/*.jpg and eval/ocr/worksheets/manifest.json
"""

import json
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = Path(__file__).resolve().parent / "worksheets"
FONTS = "/usr/share/fonts/liberation/"
PRINT = FONTS + "LiberationSerif-Regular.ttf"
PRINT_BOLD = FONTS + "LiberationSerif-Bold.ttf"
HAND = FONTS + "LiberationSerif-Italic.ttf"

# id, style, grade, subject, [lines], relevant-topic regex
SHEETS = [
    ("p5-maths-fractions", "print", "B5", "Mathematics", [
        "Class 5 Mathematics - Exercise 4", "Name: ____________", "",
        "1. Add: 3/4 + 2/5", "2. Subtract: 7/8 - 1/2",
        "3. Kofi ate 1/3 of a pizza and Ama ate 1/4 of it.", "    What fraction did they eat altogether?"], r"fraction"),
    ("p4-english-nouns", "print", "B4", "English Language", [
        "English Language - Class 4", "", "Underline the nouns in each sentence.", "",
        "1. The dog ran to the market.", "2. Ama gave her mother a basket."], r"noun"),
    ("p6-science-electricity", "print", "B6", "Science", [
        "Science - Class 6 Homework", "",
        "1. Name three sources of electricity.", "2. Draw a simple circuit with a battery and a bulb."], r"electric|circuit"),
    ("jhs2-maths-equations", "print", "B8", "Mathematics", [
        "JHS 2 Mathematics", "Solve for x:", "", "1. 2x + 5 = 11", "2. 3(x - 4) = 15", "3. x/2 + 3 = 9"], r"equation"),
    ("jhs2-english-letter", "print", "B8", "English Language", [
        "English Language - JHS 2", "",
        "Write a formal letter to your headteacher asking", "for permission to attend a family funeral."], r"letter"),
    ("jhs2-social-pollution", "print", "B8", "Social Studies", [
        "Social Studies - JHS 2", "", "1. Explain three effects of pollution on the environment."], r"pollut"),
    ("shs1-maths-factorise", "print", "SHS1", "Mathematics", [
        "SHS 1 Core Mathematics", "", "1. Factorise x^2 + 5x + 6", "2. Solve x^2 - 9 = 0"], r"factor|quadratic|expression|equation"),
    ("shs1-computing-algorithm", "print", "SHS1", "Computing", [
        "Computing - SHS 1", "", "1. Write an algorithm to find the largest of three numbers."], r"algorithm|flowchart|program"),
    # Short instruction + example content: the skill is in the instruction, not the sentence.
    ("p5-english-agreement", "print", "B5", "English Language", [
        "English - Class 5", "", "Fill in the blank with the correct verb.", "",
        "1. She ___ to school every day. (go / goes)", "2. The boys ___ football on Saturday. (play / plays)"], r"verb|tense|sentence|agree|grammar"),
    ("p4-english-plurals", "print", "B4", "English Language", [
        "English - Class 4", "", "Write the plural of each word.", "",
        "1. child    2. man    3. tooth    4. box"], r"plural|noun"),
    ("p5-maths-rounding", "print", "B5", "Mathematics", [
        "Class 5 Mathematics", "", "1. Round 4,567 to the nearest hundred.", "2. Round 12,849 to the nearest thousand."], r"round|place value|estimat"),
    ("p6-maths-ratio", "print", "B6", "Mathematics", [
        "Class 6 Mathematics", "", "1. A recipe uses 2 cups of flour for every 3 cups of sugar.", "    Write the ratio of flour to sugar.", "2. Share GH¢ 60 between Kofi and Ama in the ratio 1 : 2."], r"ratio|proportion"),
    ("p5-science-flower", "print", "B5", "Science", [
        "Science - Class 5", "", "1. Name the parts of a flower.", "2. State the function of the roots of a plant."], r"plant|flower|root"),
    ("p5-maths-five-questions", "print", "B5", "Mathematics", [
        "Class 5 Mathematics - Revision", "",
        "1. Add: 1/2 + 1/3", "2. Find the perimeter of a rectangle 8 cm long and 5 cm wide.",
        "3. Convert 0.75 to a percentage.", "4. What is the next number: 2, 4, 8, 16, ___ ?",
        "5. Write 5,306 in words."], r"fraction|perimeter|percent|pattern|place value"),
    ("p5-maths-handwritten", "hand", "B5", "Mathematics", [
        "1. Add 3/4 + 2/5", "     3/4 + 2/5 = 5/9", "",
        "2. Find the perimeter of a rectangle 8cm by 5cm", "     8 x 5 = 40"], r"fraction|perimeter"),
    ("jhs1-maths-handwritten", "hand", "B7", "Mathematics", [
        "Solve: 2x + 5 = 11", "     2x = 11 - 5", "     2x = 6", "     x = 3"], r"equation"),
    ("p4-english-handwritten", "hand", "B4", "English Language", [
        "Underline the nouns:", "The boy kicked the ball to his friend."], r"noun"),
]
# Images with no legible question: the reply must be UNREADABLE, never an invented question.
UNREADABLE_SHEETS = ["blank-page", "dark-blurry-page", "not-a-document"]


def paper(w=1240, h=1650):
    return Image.new("RGB", (w, h), (245, 242, 232))


def draw_print(lines):
    img = paper()
    d = ImageDraw.Draw(img)
    y = 110
    for i, line in enumerate(lines):
        font = ImageFont.truetype(PRINT_BOLD if i == 0 else PRINT, 44 if i == 0 else 40)
        d.text((100, y), line, fill=(25, 25, 25), font=font)
        y += 78
    return img


def draw_hand(lines, rng):
    """Uneven, slanted, blue-pen 'handwriting': per-letter jitter on lined paper."""
    img = paper()
    d = ImageDraw.Draw(img)
    for ly in range(160, 1600, 78):
        d.line([(60, ly), (1180, ly)], fill=(190, 205, 225), width=2)
    y = 105
    for line in lines:
        x = 100
        for ch in line:
            size = rng.randint(40, 47)
            font = ImageFont.truetype(HAND, size)
            d.text((x, y + rng.randint(-5, 5)), ch, fill=(35, 45, 150), font=font)
            x += d.textlength(ch, font=font) + rng.uniform(0, 2.5)
        y += 78
    return img


def photoify(img, rng, tilt=None, blur=0.8, dark=False):
    """Make a flat render look like a phone photo of a page."""
    w, h = img.size
    angle = tilt if tilt is not None else rng.uniform(-3.5, 3.5)
    canvas = Image.new("RGB", (w + 240, h + 240), (70, 60, 52))  # desk
    canvas.paste(img.rotate(angle, expand=True, fillcolor=(70, 60, 52)), (20, 20))
    canvas = canvas.resize((1100, int(1100 * canvas.height / canvas.width)))
    shift = rng.randint(14, 36)  # mild perspective: one edge slightly narrower
    cw, ch = canvas.size
    canvas = canvas.transform(
        canvas.size, Image.QUAD, (shift, 0, 0, ch, cw, ch, cw - shift, 0), Image.BICUBIC
    )
    arr = np.asarray(canvas).astype(np.float32)
    gx = np.linspace(rng.uniform(0.65, 0.9), 1.05, arr.shape[1])[None, :, None]  # uneven light
    gy = np.linspace(1.05, rng.uniform(0.8, 0.95), arr.shape[0])[:, None, None]
    arr = arr * gx * gy
    if dark:
        arr *= 0.28
    arr += np.random.default_rng(rng.randint(0, 10**6)).normal(0, 6, arr.shape)
    out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    return out.filter(ImageFilter.GaussianBlur(blur))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rng = random.Random(7)
    manifest = []
    for sid, style, grade, subject, lines, topic in SHEETS:
        flat = draw_hand(lines, rng) if style == "hand" else draw_print(lines)
        photo = photoify(flat, rng, blur=1.1 if style == "hand" else 0.8)
        photo.save(OUT / f"{sid}.jpg", quality=68)
        manifest.append({
            "file": f"{sid}.jpg", "grade": grade, "subject": subject, "style": style,
            "expected_lines": [l.strip() for l in lines if l.strip()], "expect_topic": topic,
            # a hand-written sheet's indented lines are the student's own working
            "has_working": style == "hand" and any(l.startswith("     ") for l in lines),
        })

    blank = photoify(paper(), rng)
    blank.save(OUT / "blank-page.jpg", quality=70)
    dark = photoify(draw_print(["1. Add 3/4 + 2/5"]), rng, blur=5.5, dark=True)
    dark.save(OUT / "dark-blurry-page.jpg", quality=55)
    sky = np.zeros((900, 1200, 3), np.uint8)
    sky[:, :, 0] = np.linspace(60, 140, 1200)
    sky[:, :, 1] = np.linspace(120, 200, 900)[:, None]
    sky[:, :, 2] = 235
    sky[620:, :, :] = (60, 130, 60)
    Image.fromarray(sky).save(OUT / "not-a-document.jpg", quality=80)
    for sid in UNREADABLE_SHEETS:
        manifest.append({"file": f"{sid}.jpg", "expect_unreadable": True})

    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print(f"wrote {len(manifest)} images + manifest.json to {OUT}")


if __name__ == "__main__":
    main()
