// The browser's YAMNet (app/web/models/yamnet, TensorFlow.js) as a worker for train_danger_sounds.py.
// stdin: uint32 count, then count x 15600 float32 samples. stdout: count x (521 scores + 1024 embedding) float32.
// Needs `npm install` in tools/ (package.json pins @tensorflow/tfjs).
import fs from 'fs';
import path from 'path';
import * as tf from '@tensorflow/tfjs';

const WIN = 15600;
const modelDir = process.argv[2];
const json = JSON.parse(fs.readFileSync(path.join(modelDir, 'model.json')));
const weights = Buffer.concat(json.weightsManifest.flatMap((g) => g.paths.map((p) => fs.readFileSync(path.join(modelDir, p)))));
const model = await tf.loadGraphModel(
  tf.io.fromMemory({
    modelTopology: json.modelTopology,
    weightSpecs: json.weightsManifest.flatMap((g) => g.weights),
    weightData: weights.buffer.slice(weights.byteOffset, weights.byteOffset + weights.byteLength),
  }),
);

let pending = Buffer.alloc(0);
let busy = Promise.resolve();
process.stdin.on('data', (chunk) => {
  pending = Buffer.concat([pending, chunk]);
  while (pending.length >= 4) {
    const count = pending.readUInt32LE(0);
    const size = 4 + count * WIN * 4;
    if (pending.length < size) break;
    const samples = new Float32Array(pending.buffer.slice(pending.byteOffset + 4, pending.byteOffset + size));
    pending = pending.subarray(size);
    busy = busy.then(() => answer(samples, count));
  }
});

async function answer(samples, count) {
  const out = new Float32Array(count * (521 + 1024));
  for (let i = 0; i < count; i++) {
    // Same as web/js/yamnet.js: mean over YAMNet's frames.
    const [s, e] = tf.tidy(() => {
      const [scores, embedding] = model.execute(tf.tensor1d(samples.subarray(i * WIN, (i + 1) * WIN)), ['Identity:0', 'Identity_1:0']);
      return [scores.mean(0), embedding.mean(0)];
    });
    out.set(await s.data(), i * 1545);
    out.set(await e.data(), i * 1545 + 521);
    s.dispose();
    e.dispose();
  }
  process.stdout.write(Buffer.from(out.buffer));
}
