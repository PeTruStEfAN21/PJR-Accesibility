(function () {
  const S = window.Store;
  const $ = id => document.getElementById(id);
  const KEY = 'ritm.tasks.v1';
  const THEME_KEY = 'ritm.theme';
  const SAMPLE_KEY = 'ritm.sample';
  const SHORTCUTS_KEY = 'ritm.shortcuts';
  const THEMES = ['system', 'light', 'dark'];
  const THEME_LABEL = { system: 'sistem', light: 'luminoasă', dark: 'întunecată' };
  /* Fiecare vedere din bara laterală: titlul ecranului, starea trimisă la Store și un filtru de termen. */
  const VIEWS = {
    all: { title: 'Toate sarcinile', status: 'all' },
    active: { title: 'De făcut', status: 'active' },
    today: { title: 'Azi', status: 'active', due: 'today' },
    overdue: { title: 'Întârziate', status: 'active', due: 'overdue' },
    done: { title: 'Finalizate', status: 'done' },
  };

  const dateFmt = new Intl.DateTimeFormat('ro-RO', { day: 'numeric', month: 'short' });
  const todayStr = () => S.dateStr(new Date());
  const parseDay = str => { const [y, m, d] = str.split('-').map(Number); return new Date(y, m - 1, d); };

  /* Stocare tolerantă la erori (mod privat, date blocate). */
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch { /* ignorat */ } },
  };

  const state = {
    tasks: [],
    view: 'all', category: 'all', query: '', sort: 'smart',
    editing: null,
    /* Lista de dinainte de ultima ștergere / resetare / import, pentru „Anulează”. */
    undo: null,
    isSample: true,
    shortcuts: true,
  };

  function load() {
    const raw = store.get(KEY);
    const parsed = raw && S.parseImport(raw, todayStr());
    state.tasks = parsed || S.sampleTasks(todayStr());
    state.isSample = !parsed || store.get(SAMPLE_KEY) !== '0';
  }
  const save = () => {
    store.set(KEY, JSON.stringify(state.tasks));
    store.set(SAMPLE_KEY, state.isSample ? '1' : '0');
  };
  const announce = msg => { $('live').textContent = ''; setTimeout(() => { $('live').textContent = msg; }, 30); };

  /* --- tooltip comun pentru grafice --- */
  const tipEl = $('tip');
  let tipTimer;
  const tip = {
    show(text, e) {
      clearTimeout(tipTimer);
      tipEl.textContent = text;
      tipEl.hidden = false;
      const w = tipEl.offsetWidth;
      tipEl.style.left = Math.max(8, Math.min(window.innerWidth - w - 8, e.clientX - w / 2)) + 'px';
      tipEl.style.top = Math.max(8, e.clientY - tipEl.offsetHeight - 12) + 'px';
    },
    /* Cu întârziere, ca indicatorul să poată ajunge pe tooltip (WCAG 1.4.13). */
    hide() { clearTimeout(tipTimer); tipTimer = setTimeout(() => { tipEl.hidden = true; }, 300); },
    close() { clearTimeout(tipTimer); tipEl.hidden = true; },
  };
  tipEl.addEventListener('pointerenter', () => clearTimeout(tipTimer));
  tipEl.addEventListener('pointerleave', tip.hide);

  /* --- toast cu anulare ---
     Regiunea live rămâne mereu în pagină (goală = invizibilă), ca mesajele să fie anunțate.
     Un toast cu acțiune nu expiră (WCAG 2.2.1): stă până la Închide, Anulează sau următoarea modificare. */
  let toastTimer;
  function hideToast() {
    const t = $('toast');
    const hadFocus = t.contains(document.activeElement);
    clearTimeout(toastTimer);
    t.replaceChildren();
    if (hadFocus) $('new-text').focus();
  }
  function toastButton(label, onClick) {
    const b = document.createElement('button');
    b.type = 'button';
    b.textContent = label;
    b.addEventListener('click', onClick);
    return b;
  }
  function toast(msg, actionLabel, onAction) {
    const t = $('toast');
    clearTimeout(toastTimer);
    const text = document.createElement('span');
    text.textContent = msg;
    t.replaceChildren(text);
    if (actionLabel) t.append(toastButton(actionLabel, onAction), toastButton('Închide', () => { state.undo = null; hideToast(); }));
    else toastTimer = setTimeout(hideToast, 6000);
  }

  /* Păstrează lista curentă ca să poată fi readusă cu „Anulează” sau Ctrl+Z. */
  function snapshot() {
    state.undo = { tasks: state.tasks.slice(), isSample: state.isSample };
  }
  /* Orice altă modificare face anularea veche să nu mai aibă sens. */
  function dropUndo() {
    if (!state.undo) return;
    state.undo = null;
    hideToast();
  }

  /* După ce un rând dispare din listă, focusul trece pe rândul care i-a luat locul. */
  function visibleIndex(id) {
    return [...$('list').children].findIndex(li => li.dataset.id === id);
  }
  function focusRow(id, idx) {
    const own = document.querySelector(`[data-id="${id}"] .check`);
    if (own) { own.focus(); return; }
    const rows = $('list').children;
    const near = rows[Math.min(idx, rows.length - 1)];
    const cb = near && near.querySelector('.check');
    (cb || $('new-text')).focus();
  }

  /* --- randare listă --- */
  function dueLabel(task, today) {
    if (task.done) {
      const when = task.completedAt === today ? 'azi' : task.completedAt ? dateFmt.format(parseDay(task.completedAt)) : '';
      return when ? { cls: 'plain', text: `Finalizată ${when}` } : null;
    }
    const st = S.dueState(task, today);
    if (st === 'none' && !task.due) return null;
    const text = dateFmt.format(parseDay(task.due));
    if (st === 'overdue') return { cls: 'overdue', text: `Întârziat · ${text}` };
    if (st === 'today') return { cls: 'today', text: 'Azi' };
    return { cls: '', text: `Termen ${text}` };
  }

  function buildItem(task, today) {
    const li = document.createElement('li');
    li.className = 'item' + (task.done ? ' done' : '');
    li.dataset.id = task.id;

    const cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.className = 'check';
    cb.checked = task.done;
    cb.setAttribute('aria-label', `Marchează „${task.text}” ca ${task.done ? 'activă' : 'finalizată'}`);
    cb.addEventListener('change', () => toggle(task.id));

    const main = document.createElement('div');
    main.className = 'item-main';
    const text = document.createElement('p');
    text.className = 'item-text';
    text.textContent = task.text;
    main.appendChild(text);

    const meta = document.createElement('div');
    meta.className = 'meta';
    const cat = document.createElement('span');
    cat.textContent = S.CATEGORIES.find(c => c.id === task.category).label;
    meta.appendChild(cat);

    const prio = S.PRIORITIES.find(p => p.id === task.priority);
    if (task.priority !== 'mid') {
      const p = document.createElement('span');
      p.className = 'prio-' + task.priority;
      p.textContent = (task.priority === 'high' ? '▲ ' : '▽ ') + prio.label;
      meta.appendChild(p);
    }
    const due = dueLabel(task, today);
    if (due) {
      const d = document.createElement('span');
      d.className = due.cls === 'plain' ? '' : 'pill ' + due.cls;
      d.textContent = due.text;
      meta.appendChild(d);
    }
    main.appendChild(meta);

    const actions = document.createElement('div');
    actions.className = 'item-actions';
    const edit = document.createElement('button');
    edit.type = 'button';
    edit.className = 'icon-btn';
    edit.textContent = 'Editează';
    edit.setAttribute('aria-label', `Editează „${task.text}”`);
    edit.addEventListener('click', () => { state.editing = task.id; render(); const f = document.querySelector('.edit-form input'); if (f) f.focus(); });
    const del = document.createElement('button');
    del.type = 'button';
    del.className = 'icon-btn danger';
    del.textContent = 'Șterge';
    del.setAttribute('aria-label', `Șterge „${task.text}”`);
    del.addEventListener('click', () => remove(task.id));
    actions.append(edit, del);

    li.append(cb, main, actions);
    return li;
  }

  function option(value, label, selected) {
    const o = document.createElement('option');
    o.value = value;
    o.textContent = label;
    o.selected = !!selected;
    return o;
  }

  function buildEditor(task) {
    const li = document.createElement('li');
    li.className = 'item';
    li.dataset.id = task.id;
    const form = document.createElement('form');
    form.className = 'edit-form';
    form.style.gridColumn = '1 / -1';

    const text = document.createElement('input');
    text.type = 'text';
    text.value = task.text;
    text.maxLength = 140;
    text.setAttribute('aria-label', 'Descriere sarcină');
    const err = document.createElement('p');
    err.className = 'error';
    err.id = 'edit-error-' + task.id;
    err.setAttribute('role', 'alert');
    err.textContent = 'Descrierea nu poate fi goală.';
    err.hidden = true;
    text.setAttribute('aria-describedby', err.id);
    const cat = document.createElement('select');
    cat.setAttribute('aria-label', 'Categorie');
    S.CATEGORIES.forEach(c => cat.appendChild(option(c.id, c.label, c.id === task.category)));
    const pr = document.createElement('select');
    pr.setAttribute('aria-label', 'Prioritate');
    S.PRIORITIES.forEach(p => pr.appendChild(option(p.id, p.label, p.id === task.priority)));
    const due = document.createElement('input');
    due.type = 'date';
    due.value = task.due;
    due.setAttribute('aria-label', 'Termen');

    const ok = document.createElement('button');
    ok.type = 'submit';
    ok.className = 'btn primary';
    ok.textContent = 'Salvează';
    const cancel = document.createElement('button');
    cancel.type = 'button';
    cancel.className = 'btn';
    cancel.textContent = 'Anulează';
    cancel.addEventListener('click', () => closeEditor(task.id));

    form.addEventListener('submit', e => {
      e.preventDefault();
      const next = S.createTask({ text: text.value, category: cat.value, priority: pr.value, due: due.value }, todayStr());
      err.hidden = !!next;
      text.setAttribute('aria-invalid', next ? 'false' : 'true');
      if (!next) { text.focus(); return; }
      dropUndo();
      state.tasks = state.tasks.map(t => t.id === task.id ? { ...t, text: next.text, category: next.category, priority: next.priority, due: next.due } : t);
      closeEditor(task.id);
      save();
      render();
      announce('Sarcina a fost actualizată.');
    });
    form.addEventListener('keydown', e => { if (e.key === 'Escape') closeEditor(task.id); });
    form.append(text, cat, pr, due, ok, cancel, err);
    li.appendChild(form);
    return li;
  }

  function closeEditor(id) {
    state.editing = null;
    render();
    const btn = document.querySelector(`[data-id="${id}"] .icon-btn`);
    if (btn) btn.focus();
  }

  function render() {
    const today = todayStr();
    const list = $('list');
    const view = VIEWS[state.view];
    const visible = S.filterTasks(state.tasks, { ...state, status: view.status }, today)
      .filter(t => !view.due || S.dueState(t, today) === view.due);
    list.replaceChildren(...visible.map(t => state.editing === t.id ? buildEditor(t) : buildItem(t, today)));
    $('empty').hidden = visible.length > 0;
    $('list-total').textContent = S.countLabel(visible.length, 'sarcină', 'sarcini');
    $('hint-text').textContent = state.isSample
      ? 'Sarcinile de mai sus sunt exemple. Le poți șterge sau înlocui cu ale tale.'
      : 'Vrei să pornești din nou de la exemple?';
    $('reset').textContent = state.isSample ? 'Resetează exemplele' : 'Încarcă exemplele';
    renderHeader(today);
    renderStats(today);
  }

  /* Titlul vederii, numărătorile din bara laterală și constatarea de sub titlu. */
  function renderHeader(today) {
    $('view-title').textContent = VIEWS[state.view].title;
    const open = state.tasks.filter(t => !t.done);
    const late = open.filter(t => S.dueState(t, today) === 'overdue').sort((a, b) => a.due.localeCompare(b.due));
    const counts = {
      active: open.length,
      today: open.filter(t => S.dueState(t, today) === 'today').length,
      overdue: late.length,
    };
    document.querySelectorAll('[data-count]').forEach(c => { c.textContent = counts[c.dataset.count] || ''; });

    const f = $('finding');
    const date = parseDay(today).toLocaleDateString('ro-RO', { weekday: 'long', day: 'numeric', month: 'long' });
    f.replaceChildren(document.createTextNode(date.charAt(0).toUpperCase() + date.slice(1) + ' · '));
    if (late.length) {
      const days = Math.round((parseDay(today) - parseDay(late[0].due)) / 864e5);
      const bad = document.createElement('span');
      bad.className = 'bad';
      bad.textContent = S.countLabel(late.length, 'întârziată', 'întârziate');
      const name = document.createElement('strong');
      name.textContent = `„${late[0].text}”`;
      f.append(bad, ', cea mai veche: ', name, `, de ${days === 1 ? 'o zi' : S.countLabel(days, 'zi', 'zile')}.`);
    } else if (counts.today) {
      f.append(`Nimic întârziat. ${counts.today === 1 ? 'O sarcină are' : S.countLabel(counts.today, 'sarcină', 'sarcini') + ' au'} termen azi.`);
    } else {
      f.append('Nimic întârziat și nimic cu termen azi.');
    }
  }

  function renderStats(today) {
    const cats = S.openByCategory(state.tasks);
    const week = S.completedPerDay(state.tasks, 7, today);
    const total = week.reduce((n, d) => n + d.value, 0);
    const best = week.reduce((b, d) => (d.value > b.value ? d : b), week[0]);
    $('week-total').textContent = total;
    const openTotal = cats.reduce((n, c) => n + c.value, 0);
    $('cat-total').textContent = `${openTotal} de făcut în total`;
    $('week-unit').textContent = S.countLabel(total, 'finalizată', 'finalizate').replace(/^\d+ /, '') + ' în 7 zile';
    $('week-sub').textContent = `Azi ${week[week.length - 1].value}` +
      (best.value > 0 ? ` · cea mai bună zi: ${dayLabel(best.day).long}, ${best.value}` : '');
    Charts.categoryBars($('chart-cat'), cats);
    Charts.dailyColumns($('chart-week'), week, tip, dayLabel);
    fillTable($('table-cat'), 'Sarcini de făcut pe categorii', ['Categorie', 'De făcut'], cats.map(c => [c.label, c.value]));
    fillTable($('table-week'), 'Sarcini finalizate pe zile', ['Zi', 'Finalizate'], week.map(d => [dayLabel(d.day).long, d.value]));
  }

  function dayLabel(str) {
    const d = parseDay(str);
    return {
      short: d.toLocaleDateString('ro-RO', { weekday: 'short' }).replace('.', ''),
      date: String(d.getDate()),
      long: d.toLocaleDateString('ro-RO', { weekday: 'long', day: 'numeric', month: 'long' }),
    };
  }

  function fillTable(host, caption, head, rows) {
    const table = document.createElement('table');
    const cap = document.createElement('caption');
    cap.textContent = caption;
    const thead = document.createElement('thead');
    const hr = document.createElement('tr');
    head.forEach(h => { const th = document.createElement('th'); th.scope = 'col'; th.textContent = h; hr.appendChild(th); });
    thead.appendChild(hr);
    const tbody = document.createElement('tbody');
    rows.forEach(r => {
      const tr = document.createElement('tr');
      r.forEach(v => { const td = document.createElement('td'); td.textContent = v; tr.appendChild(td); });
      tbody.appendChild(tr);
    });
    table.append(cap, thead, tbody);
    host.replaceChildren(table);
  }

  /* --- acțiuni --- */
  function toggle(id) {
    const today = todayStr();
    const idx = visibleIndex(id);
    dropUndo();
    state.tasks = state.tasks.map(t => t.id === id ? S.toggleTask(t, today) : t);
    const t = state.tasks.find(x => x.id === id);
    save();
    render();
    announce(t.done ? 'Sarcină finalizată.' : 'Sarcină readusă la active.');
    focusRow(id, idx);
  }

  function remove(id) {
    const idx = visibleIndex(id);
    snapshot();
    state.tasks = state.tasks.filter(t => t.id !== id);
    save();
    render();
    focusRow(id, idx);
    toast('Sarcină ștearsă.', 'Anulează', undo);
  }

  function undo() {
    if (!state.undo) return;
    const before = new Set(state.tasks.map(t => t.id));
    ({ tasks: state.tasks, isSample: state.isSample } = state.undo);
    state.undo = null;
    save();
    render();
    hideToast();
    announce('Acțiunea a fost anulată.');
    const back = state.tasks.find(t => !before.has(t.id));
    const cb = back && document.querySelector(`[data-id="${back.id}"] .check`);
    if (cb) cb.focus();
  }

  function setupForms() {
    const catSel = $('new-category'), prioSel = $('new-priority'), catFilter = $('cat-filter');
    S.CATEGORIES.forEach(c => catSel.appendChild(option(c.id, c.label)));
    S.PRIORITIES.forEach(p => prioSel.appendChild(option(p.id, p.label, p.id === 'mid')));
    catFilter.appendChild(option('all', 'Toate'));
    S.CATEGORIES.forEach(c => catFilter.appendChild(option(c.id, c.label)));

    $('add-form').addEventListener('submit', e => {
      e.preventDefault();
      const f = e.target;
      const t = S.createTask({ text: f.text.value, category: f.category.value, priority: f.priority.value, due: f.due.value }, todayStr());
      $('add-error').hidden = !!t;
      $('new-text').setAttribute('aria-invalid', t ? 'false' : 'true');
      if (!t) { $('new-text').focus(); return; }
      dropUndo();
      state.tasks.unshift(t);
      state.isSample = false;
      f.text.value = '';
      f.due.value = '';
      save();
      render();
      announce('Sarcină adăugată.');
      $('new-text').focus();
    });

    $('search').addEventListener('input', e => { state.query = e.target.value; render(); });
    catFilter.addEventListener('change', e => { state.category = e.target.value; render(); });
    $('sort').addEventListener('change', e => { state.sort = e.target.value; render(); });

    document.querySelectorAll('.nav-item').forEach(b => b.addEventListener('click', () => {
      state.view = b.dataset.view;
      document.querySelectorAll('.nav-item').forEach(x => {
        if (x === b) x.setAttribute('aria-current', 'page'); else x.removeAttribute('aria-current');
      });
      render();
      setMenu(false);
      announce(`${VIEWS[state.view].title}: ${$('list-total').textContent}.`);
    }));

    document.querySelectorAll('[data-view-toggle]').forEach(b => b.addEventListener('click', () => {
      const key = b.dataset.viewToggle;
      const showTable = b.getAttribute('aria-pressed') !== 'true';
      b.setAttribute('aria-pressed', String(showTable));
      b.textContent = showTable ? 'Grafic' : 'Tabel';
      $('table-' + key).hidden = !showTable;
      $('chart-' + key).hidden = showTable;
    }));

    $('reset').addEventListener('click', () => {
      snapshot();
      state.tasks = S.sampleTasks(todayStr());
      state.isSample = true;
      save();
      render();
      toast('Am încărcat exemplele. Sarcinile tale au fost înlocuite.', 'Anulează', undo);
    });
  }

  /* --- export / import --- */
  function setupIO() {
    $('export').addEventListener('click', () => {
      const blob = new Blob([JSON.stringify(state.tasks, null, 2)], { type: 'application/json' });
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = `ritm-${todayStr()}.json`;
      a.click();
      setTimeout(() => URL.revokeObjectURL(a.href), 1000);
    });
    $('import-btn').addEventListener('click', () => $('import-file').click());
    $('import-file').addEventListener('change', async e => {
      const file = e.target.files[0];
      e.target.value = '';
      if (!file) return;
      if (file.size > 1_000_000) { toast('Fișierul este prea mare (maxim 1 MB).'); return; }
      const imported = S.parseImport(await file.text(), todayStr());
      if (!imported) { toast('Fișierul nu este un export valid Ritm.'); return; }
      snapshot();
      state.tasks = imported;
      state.isSample = false;
      save();
      render();
      toast(`Am importat ${S.countLabel(imported.length, 'sarcină', 'sarcini')}. Lista veche a fost înlocuită.`, 'Anulează', undo);
    });
  }

  /* --- temă --- */
  function applyTheme(name) {
    if (name === 'system') document.documentElement.removeAttribute('data-theme');
    else document.documentElement.setAttribute('data-theme', name);
    $('theme-label').textContent = THEME_LABEL[name];
  }
  function setupTheme() {
    let current = store.get(THEME_KEY);
    if (!THEMES.includes(current)) current = 'system';
    applyTheme(current);
    $('theme').addEventListener('click', () => {
      current = THEMES[(THEMES.indexOf(current) + 1) % THEMES.length];
      store.set(THEME_KEY, current);
      applyTheme(current);
    });
  }

  /* --- scurtăturile dintr-o tastă se pot opri (WCAG 2.1.4) --- */
  function applyShortcuts() {
    document.documentElement.classList.toggle('no-shortcuts', !state.shortcuts);
    $('shortcuts-label').textContent = state.shortcuts ? 'pornite' : 'oprite';
  }
  function setupShortcuts() {
    state.shortcuts = store.get(SHORTCUTS_KEY) !== 'off';
    applyShortcuts();
    $('shortcuts').addEventListener('click', () => {
      state.shortcuts = !state.shortcuts;
      store.set(SHORTCUTS_KEY, state.shortcuts ? 'on' : 'off');
      applyShortcuts();
    });
  }

  /* --- meniul de pe ecrane înguste --- */
  const menuBtn = $('menu-btn');
  function setMenu(open) {
    if (menuBtn.getAttribute('aria-expanded') === String(open)) return;
    menuBtn.setAttribute('aria-expanded', String(open));
    menuBtn.textContent = open ? 'Închide' : 'Meniu';
    $('nav-sheet').classList.toggle('open', open);
    if (open) { const cur = document.querySelector('.nav-item[aria-current]'); if (cur) cur.focus(); }
    else menuBtn.focus();
  }
  menuBtn.addEventListener('click', () => setMenu(menuBtn.getAttribute('aria-expanded') !== 'true'));
  $('nav-sheet').addEventListener('keydown', e => { if (e.key === 'Escape') setMenu(false); });

  /* --- scurtături --- */
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') tip.close();
    const a = document.activeElement;
    /* Doar câmpurile în care se scrie; un checkbox focusat nu blochează scurtăturile. */
    const typing = /^(SELECT|TEXTAREA)$/.test(a.tagName) || a.isContentEditable ||
      (a.tagName === 'INPUT' && !/^(checkbox|radio|button|submit|reset|file|range|color)$/.test(a.type));
    if (typing) return;
    if ((e.ctrlKey || e.metaKey) && !e.altKey && !e.shiftKey && e.key.toLowerCase() === 'z' && state.undo) {
      e.preventDefault();
      undo();
      return;
    }
    if (!state.shortcuts || e.ctrlKey || e.metaKey || e.altKey) return;
    if (e.key === '/') { e.preventDefault(); $('search').focus(); }
    else if (e.key.toLowerCase() === 'n') { e.preventDefault(); $('new-text').focus(); }
  });

  load();
  setupTheme();
  setupShortcuts();
  setupForms();
  setupIO();
  render();
})();
