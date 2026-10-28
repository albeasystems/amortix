// Where the site lives. No domain exists yet, so it is published from the repository albeasystems/amortix
// at https://albeasystems.github.io/amortix/. With a custom domain set VITE_SITE_ORIGIN and BASE_PATH=/ at build time.
export const ORIGIN = import.meta.env?.VITE_SITE_ORIGIN || 'https://albeasystems.github.io';
export const BASE = import.meta.env?.BASE_URL || '/amortix/';
export const SITE_NAME = 'Amortix';
export const PUBLISHER = 'Albea Systems';
export const CONTACT = 'albeasystems@gmail.com';
export const APP_ID = '6773757657';
export const APP_STORE = `https://apps.apple.com/app/id${APP_ID}`;

// The nine languages of the app (Localizable.strings): ar de en es fr hi it pt zh-Hans.
export const LANGS = ['es', 'en', 'fr', 'it', 'de', 'pt', 'ar', 'hi', 'zh'];
export const LOCALES = { es: 'es_ES', en: 'en_US', fr: 'fr_FR', it: 'it_IT', de: 'de_DE', pt: 'pt_BR', ar: 'ar_AE', hi: 'hi_IN', zh: 'zh_CN' };
export const INTL = { es: 'es-ES', en: 'en-GB', fr: 'fr-FR', it: 'it-IT', de: 'de-DE', pt: 'pt-BR', ar: 'ar-u-nu-latn', hi: 'hi-IN', zh: 'zh-CN' };
export const HREFLANG = { es: 'es', en: 'en', fr: 'fr', it: 'it', de: 'de', pt: 'pt', ar: 'ar', hi: 'hi', zh: 'zh-Hans' };
export const LANG_NAMES = { es: 'Español', en: 'English', fr: 'Français', it: 'Italiano', de: 'Deutsch', pt: 'Português', ar: 'العربية', hi: 'हिन्दी', zh: '简体中文' };
// Bump UPDATED when copy or figures change: it feeds the visible date, JSON-LD dateModified and the sitemap lastmod.
export const PUBLISHED = '2026-10-28';
export const UPDATED = '2026-10-28';
export const RTL = new Set(['ar']);
/** Privacy, terms and support are published in every language of the app (not lawyer-reviewed). */
export const LEGAL_LANGS = LANGS;

export const url = (route = '') => `${ORIGIN}${BASE}${route}`;
export const href = (route = '') => `${BASE}${route}`;
