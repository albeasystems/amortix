import { money, num } from '../format.js';

/** One bar to one scale: capital (blue) and interest (amber). The signature of the site. */
export function CostBar({ capital, interest, lang, currency = 'EUR', labels, animate = true }) {
  const total = capital + interest;
  const pc = (capital / total) * 100;
  const label = `${labels.capital} ${money(capital, lang, currency, 0)}, ${labels.interest} ${money(interest, lang, currency, 0)}`;
  return (
    <figure className={`m-0 ${animate ? 'draw-in' : ''}`} dir="ltr">
      <div role="img" aria-label={label} className="flex h-14 w-full gap-[3px] overflow-hidden sm:h-16" style={{ borderRadius: 12 }}>
        <div className="grow-x flex items-center ps-4 font-semibold" style={{ width: `${pc}%`, background: 'var(--line)', color: 'var(--on-line)', minWidth: 0 }}>
          <span className="data truncate text-sm sm:text-base">{Math.round(pc)}%</span>
        </div>
        <div className="grow-x flex items-center ps-4 font-semibold" style={{ flex: 1, background: 'var(--amber-bar)', color: '#1d1403', minWidth: 0 }}>
          <span className="data truncate text-sm sm:text-base">{Math.round(100 - pc)}%</span>
        </div>
      </div>
      <figcaption className="mt-3 grid grid-cols-2 gap-4 text-sm" dir="auto">
        <span><span className="cell-label">{labels.capital}</span><span className="data text-lg font-semibold" style={{ color: 'var(--line)' }}>{money(capital, lang, currency, 0)}</span></span>
        <span className="text-end"><span className="cell-label">{labels.interest}</span><span className="data text-lg font-semibold" style={{ color: 'var(--amber)' }}>{money(interest, lang, currency, 0)}</span></span>
      </figcaption>
    </figure>
  );
}

/** A scale whose ticks land on round numbers: at most five steps, step 1, 2, 2.5, 5 or 10 times a power of ten. */
const niceScale = (v) => {
  const p = 10 ** Math.floor(Math.log10(v / 5));
  const step = [1, 2, 2.5, 5, 10].map((m) => m * p).find((x) => Math.ceil(v / x) <= 5);
  return { step, max: Math.ceil(v / step) * step };
};

/** Per-year stacked bars: capital repaid (blue) under interest paid (amber). Early years are mostly interest. */
export function YearBars({ years, lang, currency = 'EUR', labels, animate = true }) {
  const W = 960, H = 380, L = 76, R = 8, T = 14, B = 64;
  const { max, step: vstep } = niceScale(Math.max(...years.map((y) => y.principal + y.interest)));
  const iw = W - L - R, ih = H - T - B;
  const bw = iw / years.length;
  const y = (v) => T + ih - (v / max) * ih;
  const ticks = Array.from({ length: Math.round(max / vstep) + 1 }, (_, i) => i * vstep);
  const step = years.length > 20 ? 5 : years.length > 10 ? 2 : 1;
  const compact = (v) => new Intl.NumberFormat(lang === 'ar' ? 'ar-u-nu-latn' : lang, { notation: 'compact', maximumFractionDigits: 1 }).format(v);
  return (
    <figure className={`m-0 ${animate ? 'draw-in' : ''}`} dir="ltr">
      <svg className="draw" viewBox={`0 0 ${W} ${H}`} role="img" aria-label={labels.chart}>
        {ticks.map((t) => (
          <g key={t}>
            <line className="grid" x1={L} x2={W - R} y1={y(t)} y2={y(t)} />
            <text className="mute" x={L - 8} y={y(t) + 7} textAnchor="end" fontSize="20">{compact(t)}</text>
          </g>
        ))}
        {years.map((d, i) => {
          const x = L + i * bw + bw * 0.14, w = bw * 0.72;
          return (
            <g key={d.year} className="grow" style={{ '--i': i }}>
              <rect className="blue" x={x} y={y(d.principal)} width={w} height={Math.max(0, ih - (y(d.principal) - T))} rx="1.5" />
              <rect className="amberbar" x={x} y={y(d.principal + d.interest)} width={w} height={Math.max(0, y(d.principal) - y(d.principal + d.interest) - 1.5)} rx="1.5" />
            </g>
          );
        })}
        {years.map((d, i) => (d.year % step === 0 || i === 0) && (
          <text key={d.year} className="mute" x={L + i * bw + bw / 2} y={H - 36} textAnchor="middle" fontSize="20">{d.year}</text>
        ))}
        <text className="mute" x={W - R} y={H - 8} textAnchor="end" fontSize="20">{labels.yearAxis}</text>
      </svg>
      <figcaption className="mt-2 flex flex-wrap gap-x-6 gap-y-1 text-sm" dir="auto">
        <span className="flex items-center gap-2"><i className="inline-block h-3 w-3 rounded-sm" style={{ background: 'var(--line)' }} />{labels.capital}</span>
        <span className="flex items-center gap-2"><i className="inline-block h-3 w-3 rounded-sm" style={{ background: 'var(--amber-bar)' }} />{labels.interest}</span>
      </figcaption>
    </figure>
  );
}

/** Outstanding balance month by month for up to three repayment systems (line chart). */
export function BalanceLines({ series, lang, currency = 'EUR', labels, animate = true }) {
  const W = 960, H = 360, L = 76, R = 16, T = 14, B = 64;
  const n = Math.max(...series.map((s) => s.rows.length));
  const { max, step: vstep } = niceScale(Math.max(...series.map((s) => s.rows[0].balance + s.rows[0].principal)));
  const ticks = Array.from({ length: Math.round(max / vstep) + 1 }, (_, i) => i * vstep);
  const yrs = n / 12, ystep = yrs > 20 ? 5 : yrs > 10 ? 2 : 1;
  const yearTicks = Array.from({ length: Math.floor(yrs / ystep) + 1 }, (_, i) => i * ystep);
  const iw = W - L - R, ih = H - T - B;
  const x = (i) => L + (i / n) * iw;
  const y = (v) => T + ih - (v / max) * ih;
  const dash = ['none', '7 5', '2 5'];
  const compact = (v) => new Intl.NumberFormat(lang === 'ar' ? 'ar-u-nu-latn' : lang, { notation: 'compact', maximumFractionDigits: 1 }).format(v);
  const path = (rows) => `M${x(0)},${y(rows[0].balance + rows[0].principal)} ` + rows.map((r, i) => `L${x(i + 1)},${y(r.balance)}`).join(' ');
  return (
    <figure className="m-0" dir="ltr">
      <svg className="draw" viewBox={`0 0 ${W} ${H}`} role="img" aria-label={labels.chart}>
        {ticks.map((t) => (
          <g key={t}>
            <line className="grid" x1={L} x2={W - R} y1={y(t)} y2={y(t)} />
            <text className="mute" x={L - 8} y={y(t) + 7} textAnchor="end" fontSize="20">{compact(t)}</text>
          </g>
        ))}
        {series.map((s, k) => (
          <path key={s.id} d={path(s.rows)} className="linepath" strokeWidth="2.25" strokeDasharray={dash[k]} strokeLinecap="round" />
        ))}
        {yearTicks.map((t) => (
          <text key={t} className="mute" x={x(t * 12)} y={H - 36} textAnchor={t === 0 ? 'start' : 'middle'} fontSize="20">{t}</text>
        ))}
        <text className="mute" x={W - R} y={H - 8} textAnchor="end" fontSize="20">{labels.yearAxis}</text>
      </svg>
      <figcaption className="mt-2 flex flex-wrap gap-x-6 gap-y-1 text-sm" dir="auto">
        {series.map((s, k) => (
          <span key={s.id} className="flex items-center gap-2">
            <svg width="28" height="8" aria-hidden="true"><line x1="0" x2="28" y1="4" y2="4" stroke="var(--ink)" strokeWidth="2.25" strokeDasharray={dash[k]} strokeLinecap="round" /></svg>{s.name}
          </span>
        ))}
      </figcaption>
    </figure>
  );
}

export { num };
