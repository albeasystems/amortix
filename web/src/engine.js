// Port of amortix/Services/FinancialCalculator.swift. Same formulas, same rounding behaviour, so every
// figure on the site is one the app would show. engine.test.js pins the figures used in the page copy.

export function monthlyPayment(capital, r, n) {
  if (Math.abs(r) <= 1e-12) return capital / n;
  const e = (1 + r) ** n;
  return (capital * (r * e)) / (e - 1);
}

/** Euribor (or any index) plus spread, never below zero. */
export const variableRate = (index, spread) => Math.max(0, index + spread);

/** Runs a fixed payment month by month until the balance is gone. */
export function repay(capital, payment, r, maxMonths) {
  let balance = capital, interest = 0, months = 0;
  while (balance > 0.005 && months < maxMonths) {
    const i = balance * r;
    const principal = Math.min(payment - i, balance);
    if (!(principal > 0)) break;
    interest += i; balance -= principal; months += 1;
  }
  return { months, interest };
}

function table(capital, payment, r, months) {
  const rows = [];
  let balance = capital;
  for (let period = 1; period <= months; period++) {
    const interest = balance * r;
    const principal = Math.min(payment - interest, balance);
    balance = Math.max(0, balance - principal);
    rows.push({ period, payment, principal, interest, balance });
  }
  return rows;
}

/** French (constant payment), linear (constant principal) or American (interest only, bullet at the end). */
export function schedule(capital, r, n, system = 'french') {
  if (n <= 0) return [];
  const rows = [];
  if (system === 'french') {
    const payment = monthlyPayment(capital, r, n);
    let balance = capital;
    for (let period = 1; period <= n; period++) {
      const interest = balance * r;
      const principal = Math.min(payment - interest, balance);
      balance = Math.max(0, balance - principal);
      rows.push({ period, payment: interest + principal, principal, interest, balance });
    }
  } else if (system === 'linear') {
    const per = capital / n;
    let balance = capital;
    for (let period = 1; period <= n; period++) {
      const interest = balance * r;
      const principal = Math.min(per, balance);
      balance = Math.max(0, balance - principal);
      rows.push({ period, payment: interest + principal, principal, interest, balance });
    }
  } else {
    for (let period = 1; period <= n; period++) {
      const interest = capital * r;
      const principal = period === n ? capital : 0;
      rows.push({ period, payment: interest + principal, principal, interest, balance: period === n ? 0 : capital });
    }
  }
  return rows;
}

const sum = (rows, k) => rows.reduce((a, x) => a + x[k], 0);

/**
 * input: { capital, years, type: 'fixed'|'variable'|'mixed', system, tin, index, spread, fixedYears }
 * Rates are annual percentages. Mixed ignores `system` (two French phases), like the app.
 */
export function mortgage(input) {
  const { capital, years, type } = input;
  const n = Math.round(years * 12);
  if (type === 'mixed') {
    const fixedMonths = Math.min(Math.max(1, Math.round(input.fixedYears * 12)), n);
    const rem = n - fixedMonths;
    const rFixed = input.tin / 12 / 100;
    const p1 = monthlyPayment(capital, rFixed, n);
    const phase1 = table(capital, p1, rFixed, fixedMonths);
    const balanceAfterFixed = phase1.length ? phase1[phase1.length - 1].balance : capital;
    const vr = variableRate(input.index, input.spread);
    const rVar = vr / 12 / 100;
    let p2 = 0, phase2 = [];
    if (rem > 0 && balanceAfterFixed > 0.01) {
      p2 = monthlyPayment(balanceAfterFixed, rVar, rem);
      phase2 = table(balanceAfterFixed, p2, rVar, rem).map((x) => ({ ...x, period: fixedMonths + x.period }));
    }
    const totalCost = p1 * fixedMonths + p2 * rem;
    return { payment: p1, fixedPayment: p1, variablePayment: p2, fixedMonths, balanceAfterFixed, variableRate: vr,
      totalInterest: totalCost - capital, totalCost, rows: [...phase1, ...phase2], months: n, constant: false };
  }
  const annual = type === 'variable' ? variableRate(input.index, input.spread) : input.tin;
  const rows = schedule(capital, annual / 12 / 100, n, input.system || 'french');
  const totalInterest = sum(rows, 'interest');
  return { payment: rows[0]?.payment ?? 0, totalInterest, totalCost: capital + totalInterest, rows, months: n,
    constant: (input.system || 'french') === 'french', lastPayment: rows[rows.length - 1]?.payment ?? 0, rate: annual };
}

/** Early repayment: keep the payment and finish sooner, or keep the term and pay less each month. */
export function partial({ capital, months, rate, amount, commission = 0 }) {
  const r = rate / 12 / 100;
  const newCapital = capital - amount;
  const current = monthlyPayment(capital, r, months);
  const originalInterest = current * months - capital;
  const shortened = repay(newCapital, current, r, months);
  const newMonths = Math.max(1, shortened.months);
  const savedTerm = originalInterest - shortened.interest;
  const newPayment = monthlyPayment(newCapital, r, months);
  const savedPayment = originalInterest - (newPayment * months - newCapital);
  const reduceTerm = { monthsSaved: Math.max(0, months - newMonths), newMonths, interestSaved: savedTerm, net: savedTerm - commission, payment: current };
  const reducePayment = { monthsSaved: 0, newMonths: months, interestSaved: savedPayment, net: savedPayment - commission, payment: newPayment };
  return { current, originalInterest, newCapital, commission, reduceTerm, reducePayment,
    recommended: reduceTerm.net >= reducePayment.net ? 'term' : 'payment' };
}

/** Payment under a range of rate moves, as the app's stress test. */
export function stress(capital, months, baseRate, deltas = [-2, -1, 0, 1, 2, 3, 4, 5]) {
  const base = monthlyPayment(capital, baseRate / 12 / 100, months);
  return deltas.map((delta) => {
    const rate = Math.max(0.01, baseRate + delta);
    const payment = monthlyPayment(capital, rate / 12 / 100, months);
    return { delta, rate, payment, diff: payment - base };
  });
}

/** Rows grouped by year, for the amortization table and the charts. */
export function byYear(rows) {
  const out = [];
  for (let i = 0; i < rows.length; i += 12) {
    const chunk = rows.slice(i, i + 12);
    out.push({ year: i / 12 + 1, principal: sum(chunk, 'principal'), interest: sum(chunk, 'interest'), payment: sum(chunk, 'payment'), balance: chunk[chunk.length - 1].balance });
  }
  return out;
}
