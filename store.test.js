// Rulează cu: node store.test.js
const assert = require('node:assert/strict');
const S = require('./store.js');

const today = '2026-10-22';
let passed = 0;
function test(name, fn) {
  fn();
  passed++;
  console.log('ok  ' + name);
}

test('addDays trece peste limita de lună și an', () => {
  assert.equal(S.addDays('2026-10-31', 1), '2026-11-01');
  assert.equal(S.addDays('2026-01-01', -1), '2025-12-31');
});

test('createTask refuză textul gol și normalizează câmpurile', () => {
  assert.equal(S.createTask({ text: '   ' }, today), null);
  const t = S.createTask({ text: ' Salut ', category: 'xxx', priority: 'yyy', due: 'azi' }, today);
  assert.equal(t.text, 'Salut');
  assert.equal(t.category, 'personal');
  assert.equal(t.priority, 'mid');
  assert.equal(t.due, '');
});

test('createTask limitează lungimea textului', () => {
  assert.equal(S.createTask({ text: 'a'.repeat(500) }, today).text.length, 140);
});

test('toggleTask setează și șterge completedAt', () => {
  const t = S.createTask({ text: 'x' }, today);
  const done = S.toggleTask(t, today);
  assert.equal(done.done, true);
  assert.equal(done.completedAt, today);
  assert.equal(S.toggleTask(done, today).completedAt, '');
});

test('dueState distinge întârziat / azi / mai târziu', () => {
  const mk = due => S.createTask({ text: 'x', due }, today);
  assert.equal(S.dueState(mk('2026-10-21'), today), 'overdue');
  assert.equal(S.dueState(mk('2026-10-22'), today), 'today');
  assert.equal(S.dueState(mk('2026-10-23'), today), 'later');
  assert.equal(S.dueState(mk(''), today), 'none');
});

test('filterTasks combină status, categorie și căutare', () => {
  const tasks = S.sampleTasks(today);
  const open = S.filterTasks(tasks, { status: 'active' }, today);
  assert.ok(open.every(t => !t.done));
  const work = S.filterTasks(tasks, { category: 'munca', query: 'RAPORT' }, today);
  assert.equal(work.length, 1);
});

test('sortarea smart pune sarcinile active înaintea celor gata', () => {
  const sorted = S.filterTasks(S.sampleTasks(today), { sort: 'smart' }, today);
  const firstDone = sorted.findIndex(t => t.done);
  assert.ok(sorted.slice(firstDone).every(t => t.done));
});

test('completedPerDay returnează exact N zile, ultima fiind azi', () => {
  const series = S.completedPerDay(S.sampleTasks(today), 7, today);
  assert.equal(series.length, 7);
  assert.equal(series[6].day, today);
  assert.equal(series[6].value, 2);
});

test('openByCategory numără doar sarcinile active', () => {
  const total = S.openByCategory(S.sampleTasks(today)).reduce((s, c) => s + c.value, 0);
  assert.equal(total, S.summary(S.sampleTasks(today), today).open);
});

test('parseImport respinge JSON invalid și sare peste înregistrări stricate', () => {
  assert.equal(S.parseImport('nu e json', today), null);
  assert.equal(S.parseImport('{"a":1}', today), null);
  const out = S.parseImport('[{"text":"ok","done":true},{"text":""},{}]', today);
  assert.equal(out.length, 1);
  assert.equal(out[0].done, true);
  assert.equal(out[0].completedAt, today);
});

test('exportul urmat de import păstrează id-ul și data creării', () => {
  const original = S.sampleTasks(today);
  const back = S.parseImport(JSON.stringify(original), today);
  assert.deepEqual(back, original);
});

test('parseImport nu cade la elemente null sau primitive', () => {
  const out = S.parseImport('[null, 3, "x", [], {"text":"bun"}]', today);
  assert.equal(out.length, 1);
  assert.equal(out[0].text, 'bun');
});

test('parseImport dă id nou duplicatelor', () => {
  const out = S.parseImport('[{"id":"x1","text":"A"},{"id":"x1","text":"B"}]', today);
  assert.equal(out[0].id, 'x1');
  assert.notEqual(out[1].id, 'x1');
});

test('datele care nu există în calendar sunt respinse', () => {
  assert.equal(S.isDate('2026-02-31'), false);
  assert.equal(S.isDate('2026-13-01'), false);
  assert.equal(S.isDate('2028-02-29'), true);
  assert.equal(S.createTask({ text: 'x', due: '2026-02-31' }, today).due, '');
  const [t] = S.parseImport('[{"text":"x","createdAt":"2026-00-10","done":true,"completedAt":"2026-04-31"}]', today);
  assert.equal(t.createdAt, today);
  assert.equal(t.completedAt, today);
});

test('countLabel folosește pluralul românesc', () => {
  assert.equal(S.countLabel(0, 'sarcină', 'sarcini'), '0 sarcini');
  assert.equal(S.countLabel(1, 'sarcină', 'sarcini'), '1 sarcină');
  assert.equal(S.countLabel(19, 'sarcină', 'sarcini'), '19 sarcini');
  assert.equal(S.countLabel(20, 'sarcină', 'sarcini'), '20 de sarcini');
  assert.equal(S.countLabel(101, 'sarcină', 'sarcini'), '101 sarcini');
  assert.equal(S.countLabel(100, 'sarcină', 'sarcini'), '100 de sarcini');
});

console.log(`\n${passed} teste trecute`);
