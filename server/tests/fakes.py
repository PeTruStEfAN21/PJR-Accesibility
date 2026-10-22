"""A stand-in for anthropic.AsyncAnthropic that replays scripted responses."""

import json
from types import SimpleNamespace


def text_response(text: str, stop_reason: str = "end_turn") -> SimpleNamespace:
    return SimpleNamespace(stop_reason=stop_reason, content=[SimpleNamespace(type="text", text=text)])


def json_response(data: dict) -> SimpleNamespace:
    return text_response(json.dumps(data))


def tool_use_response(*calls: tuple[str, str, dict]) -> SimpleNamespace:
    blocks = [SimpleNamespace(type="thinking", thinking="")]
    blocks += [SimpleNamespace(type="tool_use", id=call_id, name=name, input=args) for call_id, name, args in calls]
    return SimpleNamespace(stop_reason="tool_use", content=blocks)


class FakeAnthropic:
    def __init__(self, *responses: SimpleNamespace) -> None:
        self._responses = list(responses)
        self.calls: list[dict] = []
        self.beta = SimpleNamespace(messages=SimpleNamespace(create=self._create))

    async def _create(self, **kwargs) -> SimpleNamespace:
        # Snapshot messages: the agent keeps appending to the same list.
        self.calls.append({**kwargs, "messages": list(kwargs.get("messages", []))})
        return self._responses.pop(0)
