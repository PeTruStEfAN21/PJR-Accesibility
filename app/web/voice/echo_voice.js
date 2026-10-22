// Speaker recognition for the presenter page: the microphone at 16 kHz into a 30 s buffer, and the
// ReDimNet2 speaker model (speaker.onnx) through onnxruntime-web, on WebGPU when the laptop has it,
// otherwise WebAssembly. Audio stays in this page; only the caption text goes over the network.
// Used from Dart through `window.echoVoice` (app/lib/core/voice/voice_engine_web.dart); the clarity coach
// reads the same microphone chunk by chunk (app/lib/features/coach/coach_audio_web.dart).
(function () {
  const SAMPLE_RATE = 16000;
  const BUFFER_SECONDS = 30; // enrollment reads about 20 s
  const BASE = new URL('voice/', document.baseURI);

  let sessionPromise = null;
  let context = null;
  let stream = null;
  const ring = new Float32Array(SAMPLE_RATE * BUFFER_SECONDS);
  let writeAt = 0;
  let filled = 0;
  const chunkListeners = new Set();

  function session() {
    if (!sessionPromise) {
      sessionPromise = (async () => {
        ort.env.wasm.wasmPaths = new URL('ort/', BASE).href;
        const model = new URL('speaker.onnx', BASE).href;
        for (const provider of ['webgpu', 'wasm']) {
          try {
            const created = await ort.InferenceSession.create(model, { executionProviders: [provider] });
            window.echoVoice.provider = provider;
            return created;
          } catch (error) {
            console.warn(`echoVoice: ${provider} unavailable`, error);
          }
        }
        throw new Error('echoVoice: the speaker model could not be loaded');
      })();
      sessionPromise.catch(() => { sessionPromise = null; });
    }
    return sessionPromise;
  }

  function push(chunk) {
    for (let i = 0; i < chunk.length; i++) {
      ring[writeAt] = chunk[i];
      writeAt = (writeAt + 1) % ring.length;
    }
    filled = Math.min(filled + chunk.length, ring.length);
    chunkListeners.forEach((listener) => listener(chunk));
  }

  async function openMicrophone() {
    if (!context) {
      stream = await navigator.mediaDevices.getUserMedia({
        // Raw voice: processing meant for calls changes what the model hears.
        audio: { channelCount: 1, echoCancellation: false, noiseSuppression: false, autoGainControl: false },
      });
      context = new AudioContext({ sampleRate: SAMPLE_RATE });
      await context.audioWorklet.addModule(new URL('capture_worklet.js', BASE).href);
      const source = context.createMediaStreamSource(stream);
      const capture = new AudioWorkletNode(context, 'echo-capture');
      capture.port.onmessage = (event) => push(event.data);
      source.connect(capture);
    }
    await context.resume();
  }

  window.echoVoice = {
    provider: '',

    async start() {
      try {
        await session();
        await openMicrophone();
        return true;
      } catch (error) {
        console.warn('echoVoice: could not start', error);
        return false;
      }
    },

    // The microphone without the speaker model (the clarity coach, when no voice was learned).
    async startCapture() {
      try {
        await openMicrophone();
        return true;
      } catch (error) {
        console.warn('echoVoice: could not open the microphone', error);
        return false;
      }
    },

    // Every chunk of 2048 samples as it arrives; the audio thread keeps them coming in a background tab.
    onChunk(listener) {
      chunkListeners.add(listener);
    },

    offChunk(listener) {
      chunkListeners.delete(listener);
    },

    stop() {
      if (stream) stream.getTracks().forEach((track) => track.stop());
      if (context) context.close();
      stream = null;
      context = null;
      writeAt = 0;
      filled = 0;
    },

    // The last `seconds` of audio, oldest first.
    recent(seconds) {
      const n = Math.min(Math.round(seconds * SAMPLE_RATE), filled);
      const out = new Float32Array(n);
      const start = (writeAt - n + ring.length) % ring.length;
      for (let i = 0; i < n; i++) out[i] = ring[(start + i) % ring.length];
      return out;
    },

    async embed(samples) {
      const model = await session();
      const audio = new ort.Tensor('float32', Float32Array.from(samples), [1, samples.length]);
      const output = await model.run({ audio });
      return Float32Array.from(output.embedding.data);
    },

    // Plays 16 kHz samples back (reviewing a test meeting).
    async play(samples) {
      const player = new AudioContext({ sampleRate: SAMPLE_RATE });
      const buffer = player.createBuffer(1, samples.length, SAMPLE_RATE);
      buffer.copyToChannel(Float32Array.from(samples), 0);
      const source = player.createBufferSource();
      source.buffer = buffer;
      source.connect(player.destination);
      await new Promise((resolve) => {
        source.onended = resolve;
        source.start();
      });
      await player.close();
    },

    async headJson() {
      const response = await fetch(new URL('voice_head.json', BASE).href, { cache: 'no-cache' });
      if (!response.ok) throw new Error(`voice_head.json: HTTP ${response.status}`);
      return await response.text();
    },
  };
})();
