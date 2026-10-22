// YAMNet in the browser for "Sunetul vizibil". Everything runs on this computer: no audio leaves the page.
// TensorFlow.js is only loaded when sound recognition starts, so the presenter page stays light.
window.echoYamnet = (() => {
  let model = null;
  let loading = null;

  function script(src) {
    return new Promise((resolve, reject) => {
      const tag = document.createElement('script');
      tag.src = src;
      tag.onload = resolve;
      tag.onerror = () => reject(new Error('Cannot load ' + src));
      document.head.appendChild(tag);
    });
  }

  async function load() {
    if (model) return;
    loading ??= (async () => {
      if (!window.tf) await script('js/tf.min.js');
      model = await tf.loadGraphModel('models/yamnet/model.json');
    })();
    try {
      await loading;
    } catch (e) {
      loading = null;
      throw e;
    }
  }

  // One 0.975 s window at 16 kHz -> 521 scores and the 1024-value embedding (mean over YAMNet frames).
  async function run(samples) {
    const [scores, embedding] = tf.tidy(() => {
      const [s, e] = model.execute(tf.tensor1d(samples), ['Identity:0', 'Identity_1:0']);
      return [s.mean(0), e.mean(0)];
    });
    try {
      return { scores: await scores.data(), embedding: await embedding.data() };
    } finally {
      scores.dispose();
      embedding.dispose();
    }
  }

  return { load, run };
})();
