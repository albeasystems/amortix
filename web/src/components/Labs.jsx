import { useId, useMemo, useState } from 'react';
import { mortgage, partial, stress, schedule, byYear, monthlyPayment } from '../engine.js';
import { money, pct, num, duration } from '../format.js';
import { CostBar, YearBars, BalanceLines } from './Drawing.jsx';

/** Number input that keeps what the visitor typed and hands the page a clamped number. */
function Field({ label, value, onChange, unit, step = 'any', min = 0, max }) {
  const id = useId();
  return (
    <label className="field" htmlFor={id}>
      <span>{label}</span>
      <span className="input">
        <input id={id} type="number" inputMode="decimal" step={step} min={min} max={max} value={value} onChange={(e) => onChange(e.target.value)} />
        {unit && <span className="unit">{unit}</span>}
      </span>
    </label>
  );
}

function Select({ label, value, onChange, options }) {
  const id = useId();
  return (
    <label className="field" htmlFor={id}>
      <span>{label}</span>
      <span className="input">
        <select id={id} value={value} onChange={(e) => onChange(e.target.value)}>
          {options.map(([v, t]) => <option key={v} value={v}>{t}</option>)}
        </select>
        <svg className="chev" viewBox="0 0 12 12" aria-hidden="true" style={{ color: 'var(--ink-2)' }}><path d="M2.5 4.5 6 8l3.5-3.5" /></svg>
      </span>
    </label>
  );
}

const Row = ({ k, v, hot }) => (
  <div className={`dim-row ${hot ? 'hot' : ''}`}><span className="k">{k}</span><span className="lead" /><span className="v">{v}</span></div>
);

const n = (s, d = 0, lo = 0, hi = Infinity) => { const x = parseFloat(String(s).replace(',', '.')); return Number.isFinite(x) ? Math.min(hi, Math.max(lo, x)) : d; };

function YearTable({ years, lang, currency, t }) {
  return (
    <div className="overflow-x-auto">
      <table className="tbl" dir="auto">
        <thead><tr><th>{t.year}</th><th>{t.principal}</th><th>{t.interest}</th><th>{t.balance}</th></tr></thead>
        <tbody>
          {years.map((y) => (
            <tr key={y.year}><td>{y.year}</td><td>{money(y.principal, lang, currency, 0)}</td><td>{money(y.interest, lang, currency, 0)}</td><td>{money(y.balance, lang, currency, 0)}</td></tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function Layout({ form, results }) {
  return (
    <div className="grid items-start gap-10 lg:grid-cols-[5fr_7fr] lg:gap-14">
      <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-1">{form}</div>
      <div className="min-w-0">{results}</div>
    </div>
  );
}

/** Mortgage calculator: fixed, variable or mixed, with the capital/interest drawing and the yearly table. */
export function MortgageLab({ lang, ui }) {
  const t = ui.lab, cur = t.currency;
  const [type, setType] = useState('mixed');
  const [capital, setCapital] = useState('100000');
  const [years, setYears] = useState('30');
  const [tin, setTin] = useState('3.5');
  const [fixedYears, setFixedYears] = useState('5');
  const [index, setIndex] = useState('3.75');
  const [spread, setSpread] = useState('0.75');
  const [open, setOpen] = useState(false);
  const input = { capital: n(capital, 100000, 1000), years: n(years, 30, 1, 40), type, system: 'french', tin: n(tin, 3.5, 0, 25), fixedYears: Math.min(n(fixedYears, 5, 1, 39), n(years, 30, 1, 40) - 0.0833), index: n(index, 3.75, -2, 15), spread: n(spread, 0.75, 0, 10) };
  const m = useMemo(() => mortgage(input), [type, capital, years, tin, fixedYears, index, spread]);
  const yrs = byYear(m.rows);
  return (
    <Layout
      form={<>
        <Field label={t.capital} value={capital} onChange={setCapital} unit={cur} step="1000" />
        <Field label={t.years} value={years} onChange={setYears} unit={t.yearsUnit} step="1" max="40" />
        <Select label={t.type} value={type} onChange={setType} options={[['fixed', t.fixed], ['variable', t.variable], ['mixed', t.mixed]]} />
        {type !== 'variable' && <Field label={type === 'mixed' ? t.tinFixed : t.tin} value={tin} onChange={setTin} unit="%" step="0.05" />}
        {type === 'mixed' && <Field label={t.fixedYears} value={fixedYears} onChange={setFixedYears} unit={t.yearsUnit} step="1" />}
        {type !== 'fixed' && <Field label={t.index} value={index} onChange={setIndex} unit="%" step="0.05" min={-2} />}
        {type !== 'fixed' && <Field label={t.spread} value={spread} onChange={setSpread} unit="%" step="0.05" />}
      </>}
      results={<>
        <div aria-live="polite">
          <Row k={type === 'mixed' ? t.fixedPayment : t.payment} v={money(m.payment, lang, cur)} />
          {type === 'mixed' && <Row k={t.variablePayment} v={money(m.variablePayment, lang, cur)} />}
          <Row k={t.totalCost} v={money(m.totalCost, lang, cur, 0)} />
          <Row hot k={t.totalInterest} v={money(m.totalInterest, lang, cur, 0)} />
        </div>
        <div className="mt-8"><CostBar capital={input.capital} interest={m.totalInterest} lang={lang} currency={cur} labels={t} animate={false} /></div>
        <div className="mt-8"><YearBars years={yrs} lang={lang} currency={cur} labels={t} animate={false} /></div>
        <details className="mt-6" open={open} onToggle={(e) => setOpen(e.currentTarget.open)}>
          <summary className="stamp stamp-quiet !inline-flex">{t.showTable}</summary>
          <div className="mt-4"><YearTable years={yrs} lang={lang} currency={cur} t={t} /></div>
        </details>
      </>}
    />
  );
}

/** Early repayment: reduce the term or reduce the payment, with an optional cancellation fee. */
export function PartialLab({ lang, ui }) {
  const t = ui.lab, cur = t.currency;
  const [capital, setCapital] = useState('150000');
  const [years, setYears] = useState('22');
  const [rate, setRate] = useState('3.2');
  const [amount, setAmount] = useState('20000');
  const [fee, setFee] = useState('0.5');
  const cap = n(capital, 150000, 1000), amt = Math.min(n(amount, 20000), cap - 1);
  const p = useMemo(() => partial({ capital: cap, months: Math.round(n(years, 22, 1, 40) * 12), rate: n(rate, 3.2, 0, 25), amount: amt, commission: (amt * n(fee, 0.5, 0, 10)) / 100 }), [capital, years, rate, amount, fee]);
  const unit = { year: t.yearUnit, years: t.yearsUnit, month: t.monthUnit, months: t.monthsUnit };
  const cols = [['term', t.reduceTerm, p.reduceTerm], ['payment', t.reducePayment, p.reducePayment]];
  return (
    <Layout
      form={<>
        <Field label={t.pending} value={capital} onChange={setCapital} unit={cur} step="1000" />
        <Field label={t.remaining} value={years} onChange={setYears} unit={t.yearsUnit} step="1" max="40" />
        <Field label={t.currentRate} value={rate} onChange={setRate} unit="%" step="0.05" />
        <Field label={t.amount} value={amount} onChange={setAmount} unit={cur} step="1000" />
        <Field label={t.fee} value={fee} onChange={setFee} unit="%" step="0.1" />
      </>}
      results={<div aria-live="polite">
        <Row k={t.currentPayment} v={money(p.current, lang, cur)} />
        <Row k={t.commission} v={money(p.commission, lang, cur)} />
        <div className="mt-6 grid gap-4 sm:grid-cols-2">
          {cols.map(([id, title, o]) => (
            <div key={id} className="panel p-5" style={p.recommended === id ? { borderColor: 'var(--line)', borderWidth: 2 } : undefined}>
              <div className="flex items-start justify-between gap-3"><h3 className="h3">{title}</h3>{p.recommended === id && <span className="chip" style={{ color: 'var(--line)' }}>{t.recommended}</span>}</div>
              <dl className="mt-4 grid gap-3 text-sm">
                <div><dt className="cell-label">{t.newPayment}</dt><dd className="data m-0 text-lg font-semibold">{money(o.payment, lang, cur)}</dd></div>
                <div><dt className="cell-label">{t.newTerm}</dt><dd className="data m-0 text-lg font-semibold">{duration(o.newMonths, unit)}</dd></div>
                <div><dt className="cell-label">{t.interestSaved}</dt><dd className="data m-0 text-lg font-semibold">{money(o.interestSaved, lang, cur, 0)}</dd></div>
                <div><dt className="cell-label">{t.netSaving}</dt><dd className="data m-0 text-2xl font-bold" style={{ color: 'var(--amber)' }}>{money(o.net, lang, cur, 0)}</dd></div>
              </dl>
            </div>
          ))}
        </div>
        <p className="muted mt-4 text-sm">{t.partialNote}</p>
      </div>}
    />
  );
}

/** Amortization schedule under the three repayment systems. */
export function ScheduleLab({ lang, ui }) {
  const t = ui.lab, cur = t.currency;
  const [capital, setCapital] = useState('200000');
  const [years, setYears] = useState('25');
  const [rate, setRate] = useState('3.5');
  const [system, setSystem] = useState('french');
  const months = Math.round(n(years, 25, 1, 40) * 12), r = n(rate, 3.5, 0, 25) / 12 / 100, cap = n(capital, 200000, 1000);
  const all = useMemo(() => ['french', 'linear', 'american'].map((id) => ({ id, name: t[id], rows: schedule(cap, r, months, id) })), [capital, years, rate, ui]);
  const sum = (rows, k) => rows.reduce((a, x) => a + x[k], 0);
  const chosen = all.find((s) => s.id === system);
  const yrs = byYear(chosen.rows);
  return (
    <Layout
      form={<>
        <Field label={t.capital} value={capital} onChange={setCapital} unit={cur} step="1000" />
        <Field label={t.years} value={years} onChange={setYears} unit={t.yearsUnit} step="1" max="40" />
        <Field label={t.tin} value={rate} onChange={setRate} unit="%" step="0.05" />
        <Select label={t.system} value={system} onChange={setSystem} options={all.map((s) => [s.id, s.name])} />
      </>}
      results={<>
        <div className="overflow-x-auto" aria-live="polite">
          <table className="tbl" dir="auto">
            <thead><tr><th>{t.system}</th><th>{t.firstPayment}</th><th>{t.lastPayment}</th><th>{t.totalInterest}</th></tr></thead>
            <tbody>
              {all.map((s) => (
                <tr key={s.id} style={s.id === system ? { fontWeight: 650 } : undefined}>
                  <td>{s.name}</td><td>{money(s.rows[0].payment, lang, cur, 0)}</td><td>{money(s.rows[s.rows.length - 1].payment, lang, cur, 0)}</td>
                  <td style={{ color: 'var(--amber)' }}>{money(sum(s.rows, 'interest'), lang, cur, 0)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="mt-8"><BalanceLines series={all} lang={lang} currency={cur} labels={t} /></div>
        <div className="mt-8"><YearBars years={yrs} lang={lang} currency={cur} labels={t} animate={false} /></div>
        <details className="mt-6">
          <summary className="stamp stamp-quiet !inline-flex">{t.showTable}</summary>
          <div className="mt-4"><YearTable years={yrs} lang={lang} currency={cur} t={t} /></div>
        </details>
      </>}
    />
  );
}

/** Stress test: the payment if the rate moves up or down. */
export function StressLab({ lang, ui }) {
  const t = ui.lab, cur = t.currency;
  const [capital, setCapital] = useState('180000');
  const [years, setYears] = useState('25');
  const [rate, setRate] = useState('3.5');
  const rows = useMemo(() => stress(n(capital, 180000, 1000), Math.round(n(years, 25, 1, 40) * 12), n(rate, 3.5, 0, 25)), [capital, years, rate]);
  const worst = Math.max(...rows.map((x) => x.payment));
  const sign = (v) => `${v > 0 ? '+' : v < 0 ? '−' : ''}${num(Math.abs(v), lang, 0)}`;
  return (
    <Layout
      form={<>
        <Field label={t.capital} value={capital} onChange={setCapital} unit={cur} step="1000" />
        <Field label={t.years} value={years} onChange={setYears} unit={t.yearsUnit} step="1" max="40" />
        <Field label={t.tin} value={rate} onChange={setRate} unit="%" step="0.05" />
      </>}
      results={<div aria-live="polite">
        <div className="overflow-x-auto">
          <table className="tbl" dir="auto">
            <thead><tr><th>{t.change}</th><th>{t.rate}</th><th>{t.payment}</th><th>{t.diffMonth}</th></tr></thead>
            <tbody>
              {rows.map((x) => (
                <tr key={x.delta} style={x.delta === 0 ? { fontWeight: 650 } : undefined}>
                  <td>{x.delta === 0 ? t.today : `${x.delta > 0 ? '+' : '−'}${Math.abs(x.delta)} ${t.pp}`}</td>
                  <td>{pct(x.rate, lang)}</td><td>{money(x.payment, lang, cur, 0)}</td>
                  <td style={{ color: x.diff > 0 ? 'var(--amber)' : undefined }}>{x.delta === 0 ? '·' : `${sign(x.diff)} ${cur === 'EUR' ? '€' : cur}`}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="mt-8 grid gap-3" dir="ltr">
          {rows.map((x) => (
            <div key={x.delta} className="flex items-center gap-3 text-sm">
              <span className="data w-14 shrink-0 text-end muted">{x.delta > 0 ? '+' : x.delta < 0 ? '−' : ''}{Math.abs(x.delta)} {t.pp}</span>
              <span className="h-5 rounded-[5px]" style={{ width: `${(x.payment / worst) * 100}%`, maxWidth: 'calc(100% - 9rem)', background: x.delta > 0 ? 'var(--amber-bar)' : 'var(--line)', opacity: x.delta === 0 ? 1 : 0.8 }} />
              <span className="data muted">{money(x.payment, lang, cur, 0)}</span>
            </div>
          ))}
        </div>
      </div>}
    />
  );
}

export const LABS = { mortgage: MortgageLab, partial: PartialLab, schedule: ScheduleLab, stress: StressLab };
export { monthlyPayment };
