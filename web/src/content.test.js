// Every language mirrors es.js key for key, and the copy rules hold (no em-dashes, no invented proof, figures agree).
import test from 'node:test';
import assert from 'node:assert/strict';
import { content, PAGE_IDS } from './content/index.js';
import { LANGS } from './site.js';

const keys = (o, p = '') => Object.entries(o).flatMap(([k, v]) => (v && typeof v === 'object' && !Array.isArray(v) ? keys(v, `${p}${k}.`) : [`${p}${k}`]));
const base = keys(content.es).filter((k) => !k.startsWith('legal.'));

test('all nine app languages are registered', () => assert.deepEqual(LANGS.filter((l) => content[l]), LANGS));

for (const l of LANGS) {
  test(`${l}: same keys as es`, () => assert.deepEqual(keys(content[l]).filter((k) => !k.startsWith('legal.')), base));
  test(`${l}: arrays keep their length`, () => {
    assert.equal(content[l].home.faq.items.length, content.es.home.faq.items.length);
    assert.equal(content[l].home.app.views.length, 5);
    for (const id of PAGE_IDS) { assert.equal(content[l].pages[id].faq.length, 4); assert.equal(content[l].pages[id].how.paras.length, 2); }
  });
  test(`${l}: no em-dash and no invented ratings`, () => {
    const text = JSON.stringify(content[l]);
    assert.ok(!text.includes('—'), 'em-dash found');
    assert.ok(!/aggregateRating|testimonial/i.test(text));
  });
  test(`${l}: slugs are unique and url-safe`, () => {
    const s = PAGE_IDS.map((id) => content[l].pages[id].slug);
    assert.equal(new Set(s).size, s.length);
    for (const x of s) assert.match(x, /^[a-z0-9-]+$/);
  });
}
