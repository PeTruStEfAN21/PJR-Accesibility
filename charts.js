/* Grafice SVG fără dependențe. Cerneală pentru date, o singură nuanță (--hue) pentru ziua de azi. */
(function (root) {
  const NS = 'http://www.w3.org/2000/svg';

  function el(name, attrs, text) {
    const n = document.createElementNS(NS, name);
    for (const k in attrs) n.setAttribute(k, attrs[k]);
    if (text !== undefined) n.textContent = text;
    return n;
  }

  /* Coloană cu colțuri de 2px sus, dreaptă pe linia de bază. */
  function barTop(x, y, w, h, r) {
    r = Math.min(r, w / 2, h);
    return `M${x},${y + h}V${y + r}a${r},${r} 0 0 1 ${r},-${r}H${x + w - r}a${r},${r} 0 0 1 ${r},${r}V${y + h}Z`;
  }

  function bindTip(node, tip, text) {
    const show = e => tip.show(text, e);
    node.addEventListener('pointerenter', show);
    node.addEventListener('pointermove', show);
    node.addEventListener('pointerleave', tip.hide);
  }

  /* Listă ordonată în HTML: eticheta și valoarea pe un rând, o bară subțire sub ele; cea mai mare în cerneală. */
  function categoryBars(host, data) {
    const rows = [...data].sort((a, b) => b.value - a.value);
    const max = Math.max(1, ...rows.map(d => d.value));
    const ul = document.createElement('ul');
    ul.className = 'rank';
    rows.forEach(d => {
      const li = document.createElement('li');
      const label = document.createElement('span');
      label.textContent = d.label;
      const value = document.createElement('span');
      value.className = 'num';
      value.textContent = d.value;
      const track = document.createElement('span');
      track.className = 'rank-track';
      track.setAttribute('aria-hidden', 'true');
      const fill = document.createElement('span');
      fill.className = 'rank-fill' + (d.value === max ? ' top' : '');
      fill.style.width = (100 * d.value) / max + '%';
      track.appendChild(fill);
      li.append(label, value, track);
      ul.appendChild(li);
    });
    host.replaceChildren(ul);
  }

  /* Coloane pe zile: trecutul în cerneală, azi în nuanța ecranului; ultima gradație peste maxim.
     Barele nu sunt focusabile: într-un role="img" copiii nu ajung la cititorul de ecran.
     Valorile sunt în aria-label-ul graficului și în tabelul alternativ. */
  function dailyColumns(host, data, tip, dayLabel) {
    const W = 320, H = 176, left = 22, bottom = 34, top = 16, right = 0;
    const peak = Math.max(1, ...data.map(d => d.value));
    const step = peak <= 4 ? 1 : Math.ceil(peak / 4);
    const ceil = (Math.floor(peak / step) + 1) * step;
    const plotH = H - top - bottom, plotW = W - left - right;
    const slot = plotW / data.length, bw = Math.min(24, slot - 12);

    const svg = el('svg', {
      viewBox: `0 0 ${W} ${H}`,
      role: 'img',
      'aria-label': 'Sarcini finalizate pe zile: ' + data.map(d => `${dayLabel(d.day).long} ${d.value}`).join(', '),
    });
    for (let v = 0; v <= ceil; v += step) {
      const y = top + plotH - (plotH * v) / ceil;
      svg.appendChild(el('line', { class: v === 0 ? 'base' : 'grid', x1: left, x2: W - right, y1: y, y2: y }));
      svg.appendChild(el('text', { x: 0, y, 'dominant-baseline': 'middle' }, String(v)));
    }
    const maxIdx = data.reduce((best, d, i) => (d.value > data[best].value ? i : best), 0);
    data.forEach((d, i) => {
      const cx = left + slot * i + slot / 2;
      const h = (plotH * d.value) / ceil;
      const lbl = dayLabel(d.day);
      const isToday = i === data.length - 1;
      if (d.value > 0) {
        const bar = el('path', {
          class: 'bar', d: barTop(cx - bw / 2, top + plotH - h, bw, h, 2),
          fill: isToday ? 'var(--hue)' : 'var(--chart-1)',
        });
        bindTip(bar, tip, `${lbl.long}: ${d.value} finalizate`);
        svg.appendChild(bar);
      }
      if (d.value > 0 && (i === maxIdx || isToday)) {
        svg.appendChild(el('text', { class: 'val', x: cx, y: top + plotH - h - 6, 'text-anchor': 'middle' }, String(d.value)));
      }
      svg.appendChild(el('text', { class: isToday ? 'today-lbl' : '', x: cx, y: H - bottom + 16, 'text-anchor': 'middle' }, isToday ? 'azi' : lbl.short));
      svg.appendChild(el('text', { x: cx, y: H - bottom + 30, 'text-anchor': 'middle' }, lbl.date));
    });
    host.replaceChildren(svg);
  }

  root.Charts = { categoryBars, dailyColumns };
})(window);
