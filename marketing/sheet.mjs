import sharp from 'sharp';
const langs = process.argv.slice(2);
const names = ['01-inputs','02-advanced','03-results','04-chart','05-table'];
const w = 264, h = Math.round(w*2868/1320);
const comps = [];
for (let r=0;r<langs.length;r++) for (let c=0;c<names.length;c++)
  comps.push({ input: await sharp(`source/${langs[r]}/${names[c]}.png`).resize({width:w}).toBuffer(), left: c*(w+6), top: r*(h+6) });
await sharp({create:{width:names.length*(w+6),height:langs.length*(h+6),channels:3,background:'#888'}}).composite(comps).jpeg({quality:70}).toFile('/tmp/sheet.jpg');
