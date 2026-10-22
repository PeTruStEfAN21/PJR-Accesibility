"""Rebuilds app/assets/models/yamnet.tflite: the official YAMNet TFLite plus its embedding as a second output.

The official model only returns the 521 class scores. Learned location sounds need the 1024-value
embedding (layer28/reduce_mean), so this script exposes it through a DEQUANTIZE op. Scores are unchanged.

    python -m venv .venv && .venv/Scripts/pip install ai-edge-litert flatbuffers numpy
    curl -L -o yamnet.tflite https://storage.googleapis.com/mediapipe-models/audio_classifier/yamnet/float32/latest/yamnet.tflite
    .venv/Scripts/python tools/yamnet_embeddings.py yamnet.tflite app/assets/models/yamnet.tflite
"""

import sys

import flatbuffers
import numpy as np
from ai_edge_litert import schema_py_generated as schema
from ai_edge_litert.interpreter import Interpreter

EMBEDDING = b"tower0/network/layer28/reduce_mean"


def expose_embedding(src: str, dst: str) -> None:
    model = schema.ModelT.InitFromObj(schema.Model.GetRootAsModel(bytearray(open(src, "rb").read()), 0))
    graph = model.subgraphs[0]
    embedding = next(i for i, t in enumerate(graph.tensors) if t.name == EMBEDDING)
    dequantize = next(
        i
        for i, code in enumerate(model.operatorCodes)
        if max(code.builtinCode, code.deprecatedBuiltinCode) == schema.BuiltinOperator.DEQUANTIZE
    )

    output = schema.TensorT()
    output.name = b"embedding"
    output.shape = list(graph.tensors[embedding].shape)
    output.type = schema.TensorType.FLOAT32
    output.buffer = 0
    graph.tensors.append(output)

    op = schema.OperatorT()
    op.opcodeIndex = dequantize
    op.inputs = [embedding]
    op.outputs = [len(graph.tensors) - 1]
    graph.operators.append(op)
    graph.outputs = list(graph.outputs) + [len(graph.tensors) - 1]
    # The MediaPipe metadata describes a single output; drop it so nothing reads it wrongly.
    model.metadata = None
    model.metadataBuffer = None
    model.signatureDefs = None

    builder = flatbuffers.Builder(0)
    builder.Finish(model.Pack(builder), file_identifier=b"TFL3")
    open(dst, "wb").write(builder.Output())


def check(src: str, dst: str) -> None:
    """The new model gives the same scores as the original, plus a 1024-value embedding."""
    beep = (0.5 * np.sin(2 * np.pi * 3100 * np.arange(15600) / 16000)).astype(np.float32)
    results = []
    for path in (src, dst):
        interpreter = Interpreter(model_path=path)
        interpreter.allocate_tensors()
        interpreter.set_tensor(interpreter.get_input_details()[0]["index"], beep)
        interpreter.invoke()
        results.append([interpreter.get_tensor(o["index"]) for o in interpreter.get_output_details()])
    assert np.allclose(results[0][0], results[1][0]), "scores changed"
    assert results[1][1].size == 1024, "no embedding output"


if __name__ == "__main__":
    expose_embedding(sys.argv[1], sys.argv[2])
    check(sys.argv[1], sys.argv[2])
    print("ok:", sys.argv[2])
