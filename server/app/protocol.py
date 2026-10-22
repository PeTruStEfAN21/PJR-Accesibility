"""Messages exchanged over the meeting WebSocket. Mirrors app/lib/core/protocol.dart."""

from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, TypeAdapter

MAX_MESSAGE_BYTES = 4096
ROLES = ("presenter", "participant")


class _Message(BaseModel):
    model_config = ConfigDict(extra="ignore")


class Caption(_Message):
    type: Literal["caption"]
    id: str = Field(max_length=64)
    speaker: Literal["coordinator", "public"]
    text: str = Field(max_length=2000)
    final: bool
    lang: str = Field(max_length=16)
    ts: int


class Notify(_Message):
    type: Literal["notify"]
    id: str = Field(max_length=64)
    kind: Literal["question", "repeat", "slower", "custom", "hand"]
    text: str = Field(max_length=500)
    ts: int


class Seen(_Message):
    type: Literal["seen"]
    id: str = Field(max_length=64)


class Read(_Message):
    """The presenter read the participant's question out loud (by voice synthesis or themselves)."""

    type: Literal["read"]
    id: str = Field(max_length=64)
    by: Literal["voice", "speaker"]


ClientMessage = Annotated[Caption | Notify | Seen | Read, Field(discriminator="type")]
client_message = TypeAdapter(ClientMessage)

ALLOWED = {
    "presenter": {"caption", "seen", "read"},
    "participant": {"caption", "notify"},
}
