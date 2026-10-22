/* Logica pură a aplicației: fără DOM, ca să poată fi testată în Node. */
(function (root) {
  const CATEGORIES = [
    { id: 'munca', label: 'Muncă' },
    { id: 'personal', label: 'Personal' },
    { id: 'studiu', label: 'Studiu' },
    { id: 'sanatate', label: 'Sănătate' },
  ];
  const PRIORITIES = [
    { id: 'high', label: 'Urgent', rank: 0 },
    { id: 'mid', label: 'Normal', rank: 1 },
    { id: 'low', label: 'Scăzut', rank: 2 },
  ];

  const pad = n => String(n).padStart(2, '0');

  function dateStr(d) {
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  }

  function addDays(str, n) {
    const [y, m, d] = str.split('-').map(Number);
    return dateStr(new Date(y, m - 1, d + n));
  }

  /* AAAA-LL-ZZ care există în calendar (respinge 2026-02-31). */
  function isDate(str) {
    if (typeof str !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(str)) return false;
    const [y, m, d] = str.split('-').map(Number);
    return dateStr(new Date(y, m - 1, d)) === str;
  }

  /* Plural românesc: 1 sarcină, 2 sarcini, 20 de sarcini, 101 sarcini. */
  function countLabel(n, one, many) {
    if (n === 1) return `1 ${one}`;
    const r = n % 100;
    return n !== 0 && (r === 0 || r >= 20) ? `${n} de ${many}` : `${n} ${many}`;
  }

  function newId() {
    return Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
  }

  function createTask(fields, today) {
    if (!fields || typeof fields !== 'object') return null;
    const text = String(fields.text || '').trim().slice(0, 140);
    if (!text) return null;
    return {
      id: newId(),
      text,
      category: CATEGORIES.some(c => c.id === fields.category) ? fields.category : 'personal',
      priority: PRIORITIES.some(p => p.id === fields.priority) ? fields.priority : 'mid',
      due: isDate(fields.due) ? fields.due : '',
      done: false,
      createdAt: today,
      completedAt: '',
    };
  }

  function toggleTask(task, today) {
    const done = !task.done;
    return { ...task, done, completedAt: done ? today : '' };
  }

  function dueState(task, today) {
    if (!task.due || task.done) return 'none';
    if (task.due < today) return 'overdue';
    if (task.due === today) return 'today';
    return 'later';
  }

  function filterTasks(tasks, opts, today) {
    const { status = 'all', category = 'all', query = '', sort = 'smart' } = opts;
    const q = query.trim().toLowerCase();
    const out = tasks.filter(t =>
      (status === 'all' || (status === 'done' ? t.done : !t.done)) &&
      (category === 'all' || t.category === category) &&
      (!q || t.text.toLowerCase().includes(q)));

    const rank = id => PRIORITIES.find(p => p.id === id).rank;
    const byDue = (a, b) => (a.due || '9999').localeCompare(b.due || '9999');
    const sorters = {
      smart: (a, b) => a.done - b.done || byDue(a, b) || rank(a.priority) - rank(b.priority),
      due: (a, b) => byDue(a, b) || rank(a.priority) - rank(b.priority),
      priority: (a, b) => rank(a.priority) - rank(b.priority) || byDue(a, b),
      newest: (a, b) => b.createdAt.localeCompare(a.createdAt),
    };
    return out.sort(sorters[sort] || sorters.smart);
  }

  function openByCategory(tasks) {
    return CATEGORIES.map(c => ({
      id: c.id,
      label: c.label,
      value: tasks.filter(t => !t.done && t.category === c.id).length,
    }));
  }

  function completedPerDay(tasks, days, today) {
    const out = [];
    for (let i = days - 1; i >= 0; i--) {
      const day = addDays(today, -i);
      out.push({ day, value: tasks.filter(t => t.done && t.completedAt === day).length });
    }
    return out;
  }

  function summary(tasks, today) {
    return {
      open: tasks.filter(t => !t.done).length,
      overdue: tasks.filter(t => dueState(t, today) === 'overdue').length,
      doneToday: tasks.filter(t => t.done && t.completedAt === today).length,
      total: tasks.length,
    };
  }

  /* Validează un import JSON; ignoră înregistrările stricate. */
  function parseImport(text, today) {
    let data;
    try { data = JSON.parse(text); } catch { return null; }
    if (!Array.isArray(data)) return null;
    const seen = new Set();
    return data.map(raw => {
      const t = createTask(raw, today);
      if (!t) return null;
      /* Un id repetat ar lega două sarcini între ele; duplicatul primește id nou. */
      if (typeof raw.id === 'string' && /^[\w-]{1,32}$/.test(raw.id) && !seen.has(raw.id)) t.id = raw.id;
      while (seen.has(t.id)) t.id = newId();
      seen.add(t.id);
      if (isDate(raw.createdAt)) t.createdAt = raw.createdAt;
      t.done = raw.done === true;
      t.completedAt = t.done ? (isDate(raw.completedAt) ? raw.completedAt : today) : '';
      return t;
    }).filter(Boolean);
  }

  function sampleTasks(today) {
    const mk = (text, category, priority, dueOffset, doneOffset) => {
      const t = createTask({ text, category, priority, due: dueOffset === null ? '' : addDays(today, dueOffset) }, addDays(today, -6));
      if (doneOffset !== undefined) { t.done = true; t.completedAt = addDays(today, doneOffset); }
      return t;
    };
    return [
      mk('Trimite raportul lunar către echipă', 'munca', 'high', 0),
      mk('Pregătește prezentarea pentru client', 'munca', 'mid', 3),
      mk('Revizuiește cererea de modificare', 'munca', 'low', -1),
      mk('Cumpără cadou pentru ziua mamei', 'personal', 'mid', 5),
      mk('Programează mașina la service', 'personal', 'low', null),
      mk('Termină capitolul 4 din cursul de rețele', 'studiu', 'high', 2),
      mk('Rezolvă setul de exerciții de algebră', 'studiu', 'mid', 1),
      mk('Alergare ușoară de 5 km', 'sanatate', 'mid', 0),
      mk('Programare la stomatolog', 'sanatate', 'high', -2),
      mk('Plătește facturile', 'personal', 'high', -4, -4),
      mk('Citește articolul despre accesibilitate', 'studiu', 'low', null, -3),
      mk('Întâlnire de sincronizare', 'munca', 'mid', -2, -2),
      mk('Antrenament la sală', 'sanatate', 'mid', -1, -1),
      mk('Răspunde la emailurile din inbox', 'munca', 'low', 0, 0),
      mk('Pregătește lista de cumpărături', 'personal', 'low', 0, 0),
      mk('Recapitulează notițele de curs', 'studiu', 'mid', -5, -5),
      mk('Plimbare de 30 de minute', 'sanatate', 'low', -3, -3),
    ];
  }

  const api = {
    CATEGORIES, PRIORITIES, dateStr, addDays, isDate, countLabel, createTask, toggleTask, dueState,
    filterTasks, openByCategory, completedPerDay, summary, parseImport, sampleTasks,
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.Store = api;
})(typeof window !== 'undefined' ? window : globalThis);
