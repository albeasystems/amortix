// Content registry. A language appears on the site only once its file exists here, so the build
// never publishes a half-translated tree and hreflang never points at a missing page.
import es from './es.js';
import en from './en.js';
import fr from './fr.js';
import it from './it.js';
import de from './de.js';
import pt from './pt.js';
import ar from './ar.js';
import hi from './hi.js';
import zh from './zh.js';
import { legal } from './legal.js';
import { legalMore } from './legal-more.js';
const allLegal = { ...legal, ...legalMore };

// Privacy, terms and support exist in every language.
export const content = {
  es: { ...es, legal: allLegal.es },
  en: { ...en, legal: allLegal.en },
  fr: { ...fr, legal: allLegal.fr },
  it: { ...it, legal: allLegal.it },
  de: { ...de, legal: allLegal.de },
  pt: { ...pt, legal: allLegal.pt },
  ar: { ...ar, legal: allLegal.ar },
  hi: { ...hi, legal: allLegal.hi },
  zh: { ...zh, legal: allLegal.zh },
};
export const PAGE_IDS = ['mortgage', 'early-repayment', 'schedule', 'stress'];
