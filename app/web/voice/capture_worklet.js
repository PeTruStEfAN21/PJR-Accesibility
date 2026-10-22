// Runs in the audio thread: forwards the microphone (already 16 kHz mono, see echo_voice.js) to the page
// in chunks of 2048 samples. Nothing here leaves the browser.
class EchoCapture extends AudioWorkletProcessor {
  constructor() {
    super();
    this.chunk = new Float32Array(2048);
    this.filled = 0;
  }

  process(inputs) {
    const channel = inputs[0] && inputs[0][0];
    if (channel) {
      for (let i = 0; i < channel.length; i++) {
        this.chunk[this.filled++] = channel[i];
        if (this.filled === this.chunk.length) {
          this.port.postMessage(this.chunk.slice(0));
          this.filled = 0;
        }
      }
    }
    return true;
  }
}

registerProcessor('echo-capture', EchoCapture);
