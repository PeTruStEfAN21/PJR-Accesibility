"""Single-call AI features over meeting text: recap with tasks, and simplified captions."""

from collections.abc import Iterable
from typing import Any

from app.schemas import Line, SummaryResponse

MODEL = "claude-opus-5-5"
FALLBACK_BETA = "server-side-fallback-2026-07-01"

# Codes the UI ships with today. Any other ISO code still works: the model gets the code itself.
LANGUAGE_NAMES = {"ro": "Romanian", "en": "English"}
SPEAKER_LABELS = {"coordinator": "Coordinator", "public": "Audience"}


class AIRefused(Exception):
    """The model (and its fallback) declined the request."""


async def create(client: Any, **params: Any) -> Any:
    # fallbacks="default" lets the API retry a declined request on another model by itself.
    response = await client.beta.messages.create(
        model=MODEL,
        betas=[FALLBACK_BETA],
        fallbacks="default",
        **params,
    )
    if response.stop_reason == "refusal":
        raise AIRefused("The AI declined this request.")
    return response


def text_of(response: Any) -> str:
    return "".join(block.text for block in response.content if block.type == "text").strip()


def language_name(lang: str) -> str:
    return LANGUAGE_NAMES.get(lang, lang)


def render_line(line: Line) -> str:
    return f"[#{line.id}] {SPEAKER_LABELS[line.speaker]}: {line.text}"


def render_transcript(lines: Iterable[Line]) -> str:
    return "\n".join(render_line(line) for line in lines)


SUMMARY_SYSTEM = """\
You write the recap of an in-person meeting for a deaf or hard-of-hearing participant \
who followed it through live captions.

The transcript comes from speech recognition, so some words are misheard. Infer the intended \
meaning from context, but never add anything that was not said. Each line is labelled \
Coordinator (the person running the meeting) or Audience.

Write in {language}, in plain language.
- summary: 3 to 6 short sentences covering decisions, key points and open questions.
- tasks: every concrete action someone committed to or was asked to do. owner is the person \
or role named for it, or null when nobody was named. Use an empty list when there are none."""

SUMMARY_SCHEMA = {
    "type": "object",
    "properties": {
        "summary": {"type": "string"},
        "tasks": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "text": {"type": "string"},
                    "owner": {"type": ["string", "null"]},
                },
                "required": ["text", "owner"],
                "additionalProperties": False,
            },
        },
    },
    "required": ["summary", "tasks"],
    "additionalProperties": False,
}


async def summarize(client: Any, lang: str, lines: list[Line]) -> SummaryResponse:
    response = await create(
        client,
        max_tokens=16000,
        output_config={"effort": "medium", "format": {"type": "json_schema", "schema": SUMMARY_SCHEMA}},
        system=SUMMARY_SYSTEM.format(language=language_name(lang)),
        messages=[{"role": "user", "content": render_transcript(lines)}],
    )
    return SummaryResponse.model_validate_json(text_of(response))


SIMPLIFY_SYSTEM = """\
Rewrite the caption you receive in plain {language} for a reader with dyslexia or who reads \
{language} as a second language: short sentences, common words, the same meaning, nothing added. \
Reply with the rewritten text only."""


async def simplify(client: Any, lang: str, text: str) -> str:
    response = await create(
        client,
        max_tokens=4000,
        output_config={"effort": "low"},
        system=SIMPLIFY_SYSTEM.format(language=language_name(lang)),
        messages=[{"role": "user", "content": text}],
    )
    return text_of(response)
