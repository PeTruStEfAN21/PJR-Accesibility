"""HTTP request and response bodies for the AI endpoints."""

from typing import Literal

from pydantic import BaseModel, Field

# ISO 639-1 code. Adding a language needs no code change here, only a name in ai.LANGUAGE_NAMES.
Lang = Field(pattern=r"^[a-z]{2}$")


class Line(BaseModel):
    id: int = Field(ge=1)
    speaker: Literal["coordinator", "public"]
    text: str = Field(max_length=2000)


class SummaryRequest(BaseModel):
    lang: str = Lang
    lines: list[Line] = Field(min_length=1, max_length=5000)


class Task(BaseModel):
    text: str
    owner: str | None


class SummaryResponse(BaseModel):
    summary: str
    tasks: list[Task]


class SimplifyRequest(BaseModel):
    lang: str = Lang
    text: str = Field(min_length=1, max_length=2000)


class SimplifyResponse(BaseModel):
    text: str


class AskRequest(BaseModel):
    lang: str = Lang
    lines: list[Line] = Field(min_length=1, max_length=5000)
    question: str = Field(min_length=1, max_length=500)


class AskResponse(BaseModel):
    answer: str
    citations: list[int]


class AnswerCheckRequest(BaseModel):
    lang: str = Lang
    question: str = Field(min_length=1, max_length=500)
    lines: list[Line] = Field(min_length=1, max_length=200)


class AnswerCheckResponse(BaseModel):
    answered: bool
    answer: str
    line_ids: list[int]


class QuestionsRequest(BaseModel):
    lang: str = Lang
    lines: list[Line] = Field(min_length=1, max_length=20)


class QuestionsResponse(BaseModel):
    question_ids: list[int]
