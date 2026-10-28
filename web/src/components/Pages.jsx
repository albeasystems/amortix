import { content, PAGE_IDS } from '../content/index.js';
import { mortgage } from '../engine.js';
import { APP_STORE, UPDATED, INTL, PUBLISHER, href } from '../site.js';
import { money } from '../format.js';
import { Shell, calcRoute } from './Layout.jsx';
import { CostBar } from './Drawing.jsx';
import { LABS } from './Labs.jsx';
import { pageMeta } from '../seo.js';
import { captureLang } from '../captures.js';

// The worked example the whole site returns to: the one the app captures show (100.000 EUR, 30 years, mixed).
export const EXAMPLE = { capital: 100000, years: 30, type: 'mixed', tin: 3.5, index: 3.75, spread: 0.75, fixedYears: 5 };
export const example = mortgage(EXAMPLE);

function Stamp({ children, quiet }) {
  return <a href={APP_STORE} className={`stamp ${quiet ? 'stamp-quiet' : ''}`} rel="noopener">{children}</a>;
}

const FaqMark = () => (
  <svg className="faq-mark" viewBox="0 0 16 16" aria-hidden="true"><path d="M2 8h12" /><path className="v" d="M8 2v12" /></svg>
);

function Faq({ items, title, id }) {
  return (
    <section className="zone" id={id} aria-labelledby={`${id}-h`}>
      <div className="wrap grid grid-cols-1 gap-10 lg:grid-cols-12">
        <h2 id={`${id}-h`} className="h2 lg:col-span-4">{title}</h2>
        <div className="lg:col-span-8">
          {items.map(([q, a]) => (
            <details key={q} className="faq" style={{ borderTop: '1px solid var(--rule)' }}>
              <summary className="flex items-start justify-between gap-6 py-5">
                <h3 className="h3 m-0 text-[1.1rem] font-semibold">{q}</h3>
                <FaqMark />
              </summary>
              <p className="muted measure pb-6">{a}</p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}

// ---------- home ----------

export function Home({ r }) {
  const c = content[r.lang];
  const { ui, home } = c;
  const lang = r.lang;
  const cl = captureLang(lang);
  const Lab = LABS.mortgage;
  return (
    <Shell r={r}>
      <section className="zone !pt-10 md:!pt-14" aria-labelledby="h1">
        <div className="wrap grid grid-cols-1 items-start gap-10 lg:grid-cols-12 lg:gap-14">
          <div className="rise grid grid-cols-1 justify-items-start gap-7 lg:col-span-7">
            <h1 id="h1" className="h1" style={{ fontSize: 'clamp(2.3rem, 5.2vw, 4.75rem)' }}>{home.h1}</h1>
            <p className="lede measure">{home.lede}</p>
            <div className="flex flex-wrap items-center gap-x-5 gap-y-3"><Stamp>{ui.stamp}</Stamp><span className="label">iOS 17+ · iPhone · iPad</span></div>
            <figure className="m-0 mt-6 w-full max-w-xl">
              <p className="mb-4 text-lg font-medium measure">{home.caption}</p>
              <CostBar capital={EXAMPLE.capital} interest={example.totalInterest} lang={lang} labels={ui.lab} />
              <p className="label measure mt-4">{home.exampleNote}</p>
            </figure>
          </div>
          <figure className="relative m-0 mx-auto w-full max-w-[17rem] lg:max-w-[21rem] lg:col-span-5 lg:justify-self-center">
            <div className="device">
              <picture>
                <source media="(prefers-reduced-motion: reduce)" srcSet={href(`media/views/${cl}/chart.webp`)} />
                <img src={href(`media/amortix-${cl}-screen.webp`)} width="590" height="1282" alt={home.gifAlt} fetchPriority="high" />
              </picture>
            </div>
            <figcaption className="label mt-4">{home.detailLabel}</figcaption>
          </figure>
        </div>
      </section>

      <section className="zone" id="calc" aria-labelledby="calc-h">
        <div className="wrap">
          <div className="mb-12 max-w-3xl">
            <h2 id="calc-h" className="h2">{home.calc.title}</h2>
            <p className="lede mt-4 measure">{home.calc.lede}</p>
          </div>
          <Lab lang={lang} ui={ui} />
        </div>
      </section>

      <section className="zone" id="app" aria-labelledby="app-h">
        <div className="wrap">
          <h2 id="app-h" className="h2 max-w-3xl">{home.app.title}</h2>
          <p className="lede mt-4 measure">{home.app.lede}</p>
        </div>
        <ul className="rail mt-12" tabIndex={0} aria-label={home.app.title}>
          {home.app.views.map((v) => (
            <li key={v.file} className="w-[13.5rem] sm:w-[15rem] lg:w-[calc((min(100vw_-_2.5rem,76rem)_-_6rem)/5)]">
              <figure className="m-0">
                <div className="device"><img src={href(`media/views/${cl}/${v.file}.webp`)} width="600" height="1304" loading="lazy" decoding="async" alt={v.alt} /></div>
                <figcaption className="mt-4 text-sm"><span className="font-medium">{v.caption}</span></figcaption>
              </figure>
            </li>
          ))}
        </ul>
      </section>

      <Index lang={lang} title={home.index.title} lede={home.index.lede} />

      <section className="zone !py-14 md:!py-20" aria-labelledby="plans-h">
        <div className="wrap">
          <h2 id="plans-h" className="h2 max-w-3xl">{home.plans.title}</h2>
          <p className="lede mt-4 measure">{home.plans.lede}</p>
          <dl className="panel m-0 mt-10 grid grid-cols-1 overflow-hidden md:grid-cols-3">
            {home.plans.rows.map(([k, v], i) => (
              <div key={k} className={`p-6 ${i ? 'border-t md:border-t-0 md:border-s' : ''}`} style={{ borderColor: 'var(--rule)' }}>
                <dt className="h3 mb-3">{k}</dt>
                <dd className="m-0 text-[0.9375rem]">{v}</dd>
              </div>
            ))}
          </dl>
        </div>
      </section>

      <Faq id="faq" title={home.faq.title} items={home.faq.items} />

      <section className="zone !pb-20" aria-labelledby="close-h">
        <div className="wrap">
          <div className="panel flex flex-col items-start justify-between gap-8 p-8 md:flex-row md:items-center md:p-12" style={{ background: 'var(--paper-2)', borderColor: 'transparent' }}>
            <div>
              <h2 id="close-h" className="h1 max-w-[18ch]" style={{ fontSize: 'clamp(2rem, 4.6vw, 3.6rem)' }}>{home.close.title}</h2>
              <p className="muted mt-4">{home.close.lede}</p>
              <div className="mt-6 flex h-3 w-full max-w-xs gap-[3px] overflow-hidden rounded-md" aria-hidden="true" dir="ltr"><span style={{ width: '57%', background: 'var(--line)' }} /><span style={{ flex: 1, background: 'var(--amber-bar)' }} /></div>
            </div>
            <div className="flex flex-col items-start gap-3"><Stamp>{ui.stamp}</Stamp><span className="label">iOS 17+ · iPhone · iPad</span></div>
          </div>
        </div>
      </section>
    </Shell>
  );
}

/** The index of calculators: a register in two columns. */
export function Index({ lang, title, lede, skip }) {
  const c = content[lang];
  const ids = PAGE_IDS.filter((id) => id !== skip);
  return (
    <section className="zone" id="calculators" aria-labelledby="idx-h">
      <div className="wrap">
        <h2 id="idx-h" className="h2 max-w-3xl">{title}</h2>
        {lede && <p className="lede mt-4 measure">{lede}</p>}
        <ul className="mt-12 grid list-none gap-x-12 p-0 md:grid-cols-2" style={{ borderTop: '1px solid var(--rule)' }}>
          {ids.map((id) => (
            <li key={id} style={{ borderBottom: '1px solid var(--rule)' }}>
              <a href={href(calcRoute(lang, id))} className="group block py-5 no-underline">
                <span className="h3 group-hover:underline">{c.pages[id].short}</span>
                <span className="muted mt-1 block text-[0.9375rem]">{c.pages[id].blurb}</span>
              </a>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

// ---------- calculator pages ----------

export function CalcPage({ r }) {
  const c = content[r.lang];
  const { ui } = c;
  const p = c.pages[r.id];
  const Lab = LABS[p.lab];
  return (
    <Shell r={r}>
      <section className="zone !pt-10 md:!pt-14" aria-labelledby="h1">
        <div className="wrap">
          <nav aria-label="breadcrumb" className="label mb-8">
            <a href={href(`${r.lang}/`)}>Amortix</a> / <a href={href(`${r.lang}/#calculators`)}>{ui.nav.calculators}</a>
          </nav>
          <div className="rise grid grid-cols-1 gap-7">
            <h1 id="h1" className="h1 max-w-[20ch]" style={{ fontSize: 'clamp(2.1rem, 5vw, 4.2rem)' }}>{p.h1}</h1>
            <p className="lede max-w-[62ch]" style={{ color: 'var(--ink)' }}>{p.answer}</p>
            <p className="data inline-block rounded-lg px-3 py-2 text-[0.9375rem]" style={{ color: 'var(--ink-2)', background: 'var(--paper-2)' }} dir="ltr">{p.formula}</p>
            <p className="label">{ui.updated}: <time dateTime={UPDATED}>{new Intl.DateTimeFormat(INTL[r.lang], { dateStyle: 'long', timeZone: 'UTC' }).format(new Date(UPDATED))}</time> · {PUBLISHER}</p>
          </div>
        </div>
      </section>

      <section className="zone" aria-label={p.short}>
        <div className="wrap"><Lab lang={r.lang} ui={ui} /></div>
      </section>

      <section className="zone" aria-labelledby="how-h">
        <div className="wrap grid grid-cols-1 gap-10 lg:grid-cols-12">
          <h2 id="how-h" className="h2 lg:col-span-4">{p.how.title}</h2>
          <div className="grid grid-cols-1 gap-5 lg:col-span-7">
            {p.how.paras.map((t) => <p key={t} className="measure">{t}</p>)}
            <div className="mt-4"><p className="muted mb-4 text-[0.9375rem]">{ui.cta.text}</p><Stamp>{ui.stamp}</Stamp></div>
          </div>
        </div>
      </section>

      <Faq id="faq" title={c.sections.faq} items={p.faq} />
      <Index lang={r.lang} title={c.related.title} skip={r.id} />
    </Shell>
  );
}

// ---------- legal ----------

export function LegalPage({ r }) {
  const doc = content[r.lang].legal[r.id];
  return (
    <Shell r={r}>
      <section className="zone !pt-12">
        <div className="wrap grid grid-cols-1 gap-10 lg:grid-cols-12">
          <div className="lg:col-span-4">
            <h1 className="h1" style={{ fontSize: 'clamp(2rem, 4.5vw, 3.4rem)' }}>{doc.title}</h1>
            <p className="label mt-4">{doc.updated}</p>
          </div>
          <div className="grid grid-cols-1 gap-9 lg:col-span-8">
            {doc.sections.map(([h, ...ps]) => (
              <div key={h}>
                <h2 className="h3 mb-3">{h}</h2>
                <div className="grid gap-3">{ps.map((t) => <p key={t} className="measure">{t}</p>)}</div>
              </div>
            ))}
          </div>
        </div>
      </section>
    </Shell>
  );
}

export function Page({ r }) {
  if (r.page === 'home') return <Home r={r} />;
  if (r.page === 'calc') return <CalcPage r={r} />;
  return <LegalPage r={r} />;
}

export { pageMeta, money };
