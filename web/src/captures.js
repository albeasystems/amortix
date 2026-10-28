// Languages that have their own set of app captures in public/media/views/<lang>/ (and the screen loop).
// All nine app languages are captured in the iOS Simulator (marketing/capture.sh).
export const CAPTURE_LANGS = ['es', 'en', 'fr', 'it', 'de', 'pt', 'ar', 'hi', 'zh'];
export const captureLang = (lang) => (CAPTURE_LANGS.includes(lang) ? lang : 'en');
