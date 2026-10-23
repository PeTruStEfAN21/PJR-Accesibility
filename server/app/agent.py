"""The "Întreabă meetingul" agent: answers questions about a meeting by searching its transcript.

The loop is ours (bounded, testable); the model only decides which tool to call next.
"""

import re
import unicodedata
from typing import Any

from app.ai import DATA_NOT_INSTRUCTIONS, AIIncomplete, create, language_name, render_line, text_of
from app.schemas import AskResponse, Line

MAX_STEPS = 6
MAX_SEARCH_RESULTS = 8
MAX_READ_LINES = 40

SYSTEM = """\
You answer questions about an in-person meeting for a deaf or hard-of-hearing participant.

You cannot see the transcript directly: use the tools to find what was said. It has {count} \
lines, numbered #1 to #{count}. Speakers are labelled Coordinator (the person running the \
meeting) or Audience. It comes from speech recognition, so some words are misheard; search for \
synonyms or related words when a first search finds nothing.

Answer in {language}, briefly and in plain language. Back every statement with the lines it \
comes from, written like [#12]. If the transcript does not contain the answer, say so plainly \
instead of guessing.

""" + DATA_NOT_INSTRUCTIONS

TOOLS = [
    {
        "name": "search_transcript",
        "description": (
            "Find transcript lines containing any of the query words. Case and diacritics are "
            "ignored. Returns at most 8 lines, best matches first."
        ),
        "strict": True,
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "One or more words to look for."},
                "speaker": {"type": "string", "enum": ["coordinator", "public", "any"]},
            },
            "required": ["query", "speaker"],
            "additionalProperties": False,
        },
    },
    {
        "name": "read_lines",
        "description": "Read a range of consecutive lines, for context around a search hit. At most 40 lines.",
        "strict": True,
        "input_schema": {
            "type": "object",
            "properties": {
                "start": {"type": "integer", "description": "First line number, inclusive."},
                "end": {"type": "integer", "description": "Last line number, inclusive."},
            },
            "required": ["start", "end"],
            "additionalProperties": False,
        },
    },
]

_CITATION = re.compile(r"\[#(\d+)\]")
_CITATION_WITH_SPACE = re.compile(r"\s?\[#(\d+)\]")


def _normalize(text: str) -> str:
    decomposed = unicodedata.normalize("NFKD", text.casefold())
    return "".join(ch for ch in decomposed if not unicodedata.combining(ch))


def search_transcript(lines: list[Line], query: str, speaker: str) -> str:
    words = [word for word in re.findall(r"\w+", _normalize(query)) if len(word) >= 3]
    scored = []
    for line in lines:
        if speaker != "any" and line.speaker != speaker:
            continue
        text = _normalize(line.text)
        score = sum(word in text for word in words)
        if score:
            scored.append((score, line))
    if not scored:
        return f"No lines match: {query}"
    best = sorted(scored, key=lambda item: (-item[0], item[1].id))[:MAX_SEARCH_RESULTS]
    return "\n".join(render_line(line) for _, line in best)


def read_lines(lines: list[Line], start: int, end: int) -> str:
    end = min(end, start + MAX_READ_LINES - 1)
    selected = [line for line in lines if start <= line.id <= end]
    if not selected:
        return f"No lines between #{start} and #{end}."
    return "\n".join(render_line(line) for line in selected)


def _run_tool(lines: list[Line], name: str, args: dict) -> tuple[str, bool]:
    try:
        if name == "search_transcript":
            return search_transcript(lines, args["query"], args["speaker"]), False
        if name == "read_lines":
            return read_lines(lines, int(args["start"]), int(args["end"])), False
    except (KeyError, TypeError, ValueError) as exc:
        return f"Invalid arguments for {name}: {exc}", True
    return f"Unknown tool: {name}", True


async def ask(client: Any, lang: str, lines: list[Line], question: str) -> AskResponse:
    system = SYSTEM.format(count=len(lines), language=language_name(lang))
    messages: list[dict] = [{"role": "user", "content": question}]

    for step in range(1, MAX_STEPS + 1):
        params: dict[str, Any] = {}
        if step == MAX_STEPS:
            # Out of steps: make the model answer with what it has found so far.
            params["tool_choice"] = {"type": "none"}
        response = await create(
            client,
            max_tokens=16000,
            output_config={"effort": "medium"},
            system=system,
            tools=TOOLS,
            messages=messages,
            **params,
        )
        tool_calls = [block for block in response.content if block.type == "tool_use"]
        if response.stop_reason != "tool_use" or not tool_calls:
            break

        # Pass the content back unchanged: it carries thinking blocks the next turn needs.
        messages.append({"role": "assistant", "content": response.content})
        results = []
        for call in tool_calls:
            output, is_error = _run_tool(lines, call.name, call.input)
            result = {"type": "tool_result", "tool_use_id": call.id, "content": output}
            if is_error:
                result["is_error"] = True
            results.append(result)
        messages.append({"role": "user", "content": results})

    answer = text_of(response)
    if not answer:
        raise AIIncomplete("The AI gave no answer.")
    known = {line.id for line in lines}
    # A citation to a line that does not exist would send the reader looking for it: drop it from the text too.
    answer = _CITATION_WITH_SPACE.sub(lambda m: m.group(0) if int(m.group(1)) in known else "", answer)
    citations = list(dict.fromkeys(int(match) for match in _CITATION.findall(answer)))
    return AskResponse(answer=answer, citations=citations)
