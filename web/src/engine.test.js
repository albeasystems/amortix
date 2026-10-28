// Pins the figures that appear in the page copy and in the app captures (100.000 EUR, 30 years, mixed).
import test from 'node:test';
import assert from 'node:assert/strict';
import { mortgage, monthlyPayment, partial, stress, schedule, byYear } from './engine.js';

const r2 = (x) => Math.round(x * 100) / 100;

test('French payment on 100.000 at 3,5 % over 30 years', () => {
  assert.equal(r2(monthlyPayment(100000, 0.035 / 12, 360)), 449.04);
});

test('mixed mortgage matches the app capture (5 fixed years, Euribor 3,75 + 0,75)', () => {
  const m = mortgage({ capital: 100000, years: 30, type: 'mixed', tin: 3.5, index: 3.75, spread: 0.75, fixedYears: 5 });
  assert.equal(r2(m.fixedPayment), 449.04);
  assert.equal(r2(m.variablePayment), 498.57);
  assert.equal(r2(m.totalInterest), 76512.32);
  assert.equal(r2(m.totalCost), 176512.32);
  assert.equal(m.rows.length, 360);
  assert.ok(m.rows[359].balance < 0.01);
});

test('three systems: same capital repaid, different interest', () => {
  const r = 0.04 / 12;
  const sum = (rows, k) => rows.reduce((a, x) => a + x[k], 0);
  const fr = schedule(150000, r, 240, 'french'), li = schedule(150000, r, 240, 'linear'), am = schedule(150000, r, 240, 'american');
  for (const rows of [fr, li, am]) assert.ok(Math.abs(sum(rows, 'principal') - 150000) < 0.01);
  assert.ok(sum(li, 'interest') < sum(fr, 'interest'));
  assert.ok(sum(fr, 'interest') < sum(am, 'interest'));
});

test('early repayment: reducing the term saves more interest than reducing the payment', () => {
  const p = partial({ capital: 100000, months: 240, rate: 3.5, amount: 20000 });
  assert.ok(p.reduceTerm.interestSaved > p.reducePayment.interestSaved);
  assert.equal(p.recommended, 'term');
  assert.ok(p.reduceTerm.monthsSaved > 0);
  assert.ok(p.reducePayment.payment < p.current);
});

test('stress test: a rise of one point costs more than it saves a fall of one point', () => {
  const s = stress(100000, 300, 3.5);
  const up = s.find((x) => x.delta === 1).diff, down = s.find((x) => x.delta === -1).diff;
  assert.ok(up > 0 && down < 0 && up > -down);
});

test('yearly summary has one row per year and ends at zero', () => {
  const m = mortgage({ capital: 100000, years: 30, type: 'fixed', tin: 3.5 });
  const y = byYear(m.rows);
  assert.equal(y.length, 30);
  assert.ok(y[29].balance < 0.01);
});
