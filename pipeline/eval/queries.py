"""
Retrieval evaluation queries: realistic student questions with an objective relevance rule.

Each case is (query, grade, subject, relevant) where `relevant` is a regex matched against a
record's indicator text + content standard + sub-strand name. A query counts as a hit at k if
any of the top-k records (retrieved under the same grade/subject filter the app uses) matches.
Cases whose regex matches no record at all are reported as 'not covered' and left out of the
score — the curriculum simply doesn't teach that topic at that grade.
"""

CASES = [
    # --- Upper Primary: Mathematics
    ("how do I read and write big numbers like fifty thousand", "B4", "Mathematics", r"place value|number quantities|numerals"),
    ("how do I add fractions with different bottoms", "B5", "Mathematics", r"fraction"),
    ("how do I find the area of a rectangle", "B5", "Mathematics", r"area"),
    ("what is a ratio and how do I use it", "B6", "Mathematics", r"ratio"),
    ("how do I read a bar graph", "B4", "Mathematics", r"bar graph|pictograph|bar chart"),
    ("what is an angle and how do I measure it", "B5", "Mathematics", r"angle"),
    ("how do I work out percentages", "B6", "Mathematics", r"percent"),
    ("tell me how multiplication works", "B4", "Mathematics", r"multipl"),
    # --- Upper Primary: English
    ("what is a noun", "B4", "English Language", r"noun"),
    ("how do I write a letter to my friend", "B5", "English Language", r"letter"),
    ("what is the past tense of a verb", "B5", "English Language", r"tense|verb"),
    ("how do I answer questions about a story I read", "B4", "English Language", r"comprehension|read"),
    ("how do I write a good composition", "B6", "English Language", r"composition|essay|paragraph|writ"),
    ("what are adjectives", "B4", "English Language", r"adjective"),
    # --- Upper Primary: Science
    ("what are solids liquids and gases", "B4", "Science", r"solid|liquid|gas|matter"),
    ("how does electricity work", "B6", "Science", r"electric|circuit"),
    ("what do plants need to grow", "B5", "Science", r"plant"),
    ("what is the water cycle", "B5", "Science", r"water cycle|evaporat|condens"),
    ("how do magnets work", "B5", "Science", r"magnet"),
    # --- Upper Primary: Our World and Our People
    ("tell me about my family and community", "B4", "Our World and Our People", r"family|communit"),
    ("why should we take care of our environment", "B5", "Our World and Our People", r"environment"),
    ("what are my rights and responsibilities", "B6", "Our World and Our People", r"right|responsib"),
    # --- Upper Primary: Computing
    ("what is a computer", "B4", "Computing", r"computer"),
    ("how do I use the keyboard and mouse", "B4", "Computing", r"keyboard|mouse"),
    ("what is the internet", "B5", "Computing", r"internet"),
    ("how do I make a presentation with slides", "B6", "Computing", r"presentation|slide"),
    # --- JHS: Mathematics
    ("what are negative numbers and integers", "B7", "Mathematics", r"integer|negative"),
    ("how do I solve an equation for x", "B8", "Mathematics", r"equation"),
    ("what is the Pythagoras theorem", "B9", "Mathematics", r"pythag"),
    ("what are prime numbers and factors", "B7", "Mathematics", r"prime|factor"),
    ("what is probability", "B8", "Mathematics", r"probabilit"),
    ("how do I use indices and powers", "B9", "Mathematics", r"indices|index|power"),
    # --- JHS: English
    ("what are the different types of sentences", "B7", "English Language", r"sentence"),
    ("how do I write a formal letter", "B8", "English Language", r"letter"),
    ("what are similes and metaphors", "B7", "English Language", r"simile|metaphor|figur"),
    ("how do I write a summary", "B8", "English Language", r"summar"),
    # --- JHS: Science
    ("what is photosynthesis", "B8", "Science", r"photosynth"),
    ("what are acids and bases", "B7", "Science", r"acid|base"),
    ("what is force and motion", "B7", "Science", r"force|motion"),
    ("how does the digestive system work", "B8", "Science", r"digest"),
    ("how do magnets and electromagnets work", "B9", "Science", r"magnet"),
    # --- JHS: Social Studies
    ("what is pollution and what causes it", "B7", "Social Studies", r"pollut"),
    ("what are human rights", "B8", "Social Studies", r"rights"),
    ("tell me about tourism in Ghana", "B8", "Social Studies", r"tourism"),
    ("what is population growth", "B7", "Social Studies", r"population"),
    # --- JHS: Computing
    ("what are the parts of a computer", "B7", "Computing", r"hardware|input|output|components|parts of a computer"),
    ("what is an algorithm", "B8", "Computing", r"algorithm"),
    ("how do I use a spreadsheet", "B8", "Computing", r"spreadsheet"),
    ("how do I write a program", "B9", "Computing", r"program|coding|code"),
    # --- SHS
    ("what are rational and irrational numbers", "SHS1", "Mathematics", r"rational|irrational|real number"),
    ("how do I solve a quadratic equation", "SHS1", "Mathematics", r"quadratic"),
    ("what are sets and venn diagrams", "SHS1", "Mathematics", r"\bsets?\b|venn"),
    ("how do I write an argumentative essay", "SHS2", "English Language", r"argument|essay|persua"),
    ("what are figures of speech", "SHS1", "English Language", r"figur|simile|metaphor|literary"),
    ("how do I write a good paragraph", "SHS1", "English Language", r"paragraph"),
    ("what is the structure of an atom", "SHS1", "Science", r"atom"),
    ("how do cells work", "SHS1", "Science", r"cell"),
    ("what is entrepreneurship", "SHS2", "Social Studies", r"entrepreneur"),
    ("what is globalisation", "SHS3", "Social Studies", r"global"),
    ("what is a database", "SHS2", "Computing", r"database"),
    ("how do loops work in programming", "SHS1", "Computing", r"loop|iterat|program"),
    ("what is an algorithm and a flowchart", "SHS1", "Computing", r"algorithm|flowchart"),
]

# Homework-style and messy phrasing — closer to what students type or what OCR returns from a
# photographed worksheet. Harder than the clean topic questions above.
CASES += [
    ("Calculate 3/4 + 2/5", "B5", "Mathematics", r"fraction"),
    ("Find the perimeter of a rectangle with length 8cm and width 5cm", "B5", "Mathematics", r"perimeter"),
    ("Express 0.75 as a percentage", "B6", "Mathematics", r"percent|decimal"),
    ("Simplify 2x + 3x - 4", "B8", "Mathematics", r"algebra|expression|simplif"),
    ("Solve 2x + 5 = 11", "B7", "Mathematics", r"equation"),
    ("Find the mean of 4, 6, 8 and 10", "B8", "Mathematics", r"mean|average|statistic|data"),
    ("A coin is tossed. What is the probability of getting a head?", "B8", "Mathematics", r"probabilit"),
    ("The angles of a triangle are 60 and 70 degrees. Find the third angle", "B7", "Mathematics", r"triangle|angle"),
    ("Factorise x^2 + 5x + 6", "SHS1", "Mathematics", r"factor|quadratic|expression"),
    ("Underline the nouns in: The dog ran to the market.", "B4", "English Language", r"noun"),
    ("Change into past tense: She walks to school", "B5", "English Language", r"tense|past|verb"),
    ("Write a composition about my best friend", "B5", "English Language", r"composition|writ|descri"),
    ("Pick out the adjectives in the sentence", "B4", "English Language", r"adjective"),
    ("What is the difference between a simile and a metaphor?", "B7", "English Language", r"simile|metaphor|figur"),
    ("Identify the figure of speech in 'the wind whispered through the trees'", "SHS1", "English Language", r"figur|simile|metaphor|literary|personif"),
    ("Name three states of matter and give an example of each", "B4", "Science", r"matter|solid|liquid"),
    ("Explain how a simple circuit makes a bulb light up", "B6", "Science", r"electric|circuit"),
    ("List the parts of a flowering plant and what they do", "B5", "Science", r"plant|flower|part"),
    ("How does the heart pump blood around the body?", "B8", "Science", r"circul|heart|blood"),
    ("Why do we need to save water?", "B5", "Our World and Our People", r"water|environment|conserv"),
    ("Describe the role of the family in the community", "B4", "Our World and Our People", r"family|communit"),
    ("How do I save a file on the computer?", "B4", "Computing", r"file|save|folder"),
    ("What is a search engine?", "B5", "Computing", r"search|internet|browser"),
    ("Write pseudocode to add two numbers", "B9", "Computing", r"algorithm|pseudocode|program"),
    ("Define democracy", "B8", "Social Studies", r"democra|governance|government"),
    ("What are the causes of conflict and how can we resolve it?", "SHS2", "Social Studies", r"conflict|peace"),
    # typos / chatty phrasing
    ("wat is a nown", "B4", "English Language", r"noun"),
    ("how do i ad fractons", "B5", "Mathematics", r"fraction"),
    ("explain gravity to me please", "B7", "Science", r"gravit|force"),
    ("im stuck on my homework about the water cycle", "B5", "Science", r"water cycle|evaporat|condens|water"),
]
