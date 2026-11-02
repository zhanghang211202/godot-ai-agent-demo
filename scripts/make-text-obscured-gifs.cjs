// Derive text-obscured crops from immutable historical runtime recordings.
// Dependencies remain project-local in .tools/media. Never overwrite evidence.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const req = require('module').createRequire(path.resolve('.tools/media/package.json'));
const { parseGIF, decompressFrames } = req('gifuct-js');
const { GIFEncoder, quantize, applyPalette } = req('gifenc');
const battleOnly = process.argv.includes('--battle-only');
const dest = battleOnly ? 'docs/devlog/screenshots/2026-11-02-text-obscured-battle-v2' : 'docs/devlog/screenshots/2026-11-02-text-obscured-v2';
const jobs = battleOnly ? [
 ['mage-vfx','docs/devlog/screenshots/mage-vfx-v2/mage-vfx.gif',[0,0,1056,262],[[365,110,130,80],[620,110,135,80]]],
 ...['moth','golem'].map(n => [n, `docs/devlog/screenshots/mage-expansion-v1/${n}.gif`, [0,0,1056,262], [[365,110,130,80],[620,110,135,80]]]),
] : [
 ['v03-battle', 'docs/devlog/screenshots/v0.3-sample/battle-motion.gif', [12, 80, 516, 100], [[0, 44, 180, 32], [340, 44, 176, 32]]],
 ...['mage-motion','greatblade-motion','sword-motion'].map(n => [n, `docs/devlog/screenshots/c1-motion-v1/${n}.gif`, [8, 76, 704, 134], [[245, 47, 84, 48], [415, 47, 76, 48]]]),
 ...['mage-feedback','heavy-feedback','loss-feedback'].map(n => [n, `docs/devlog/screenshots/c1-feedback-v1/${n}.gif`, [8, 76, 704, 134], [[245, 47, 84, 48], [415, 47, 76, 48]]]),
 ['mage-battle', 'docs/devlog/screenshots/mage-trial-v1/mage-battle.gif', [8, 76, 704, 134], [[245, 47, 84, 48], [415, 47, 76, 48]]],
];
fs.mkdirSync(dest, { recursive: true });
const records = [];
for (const [name, input, crop, masks] of jobs) {
 const output = path.join(dest, name+'.gif');
 if (fs.existsSync(output)) throw Error(`Refusing to overwrite ${output}`);
 const bytes = fs.readFileSync(input), parsed = parseGIF(bytes), frames = decompressFrames(parsed, true);
 const sw = parsed.lsd.width, sh = parsed.lsd.height;
 let canvas = new Uint8Array(sw*sh*4), previous = null, disposal = 0, previousDims = null;
 const encoder = GIFEncoder(); let elapsed = 0, priorPixels = null;
 for (const frame of frames) {
  if (disposal === 2 && previousDims) for (let y=previousDims.top;y<previousDims.top+previousDims.height;y++) canvas.fill(0,(y*sw+previousDims.left)*4,(y*sw+previousDims.left+previousDims.width)*4);
  else if (disposal === 3 && previous) canvas = previous;
  previous = frame.disposalType === 3 ? canvas.slice() : null;
  const {left,top,width,height} = frame.dims;
  for (let y=0;y<height;y++) for (let x=0;x<width;x++) {
   const s=(y*width+x)*4, d=((y+top)*sw+x+left)*4;
   if (frame.patch[s+3]) canvas.set(frame.patch.subarray(s,s+4),d);
  }
  disposal=frame.disposalType; previousDims=frame.dims;
  const [cx,cy,cw,ch] = crop, pixels = new Uint8Array(cw*ch*4);
  for (let y=0;y<ch;y++) pixels.set(canvas.subarray(((y+cy)*sw+cx)*4,((y+cy)*sw+cx+cw)*4),y*cw*4);
  // Mosaic the known floating combat-text zones, including the background.
  for (const [mx,my,mw,mh] of masks) for(let by=my;by<my+mh;by+=8) for(let bx=mx;bx<mx+mw;bx+=8) {
   let rr=0,gg=0,bb=0,n=0;
   for(let y=by;y<Math.min(by+8,my+mh,ch);y++) for(let x=bx;x<Math.min(bx+8,mx+mw,cw);x++){const i=(y*cw+x)*4;rr+=pixels[i];gg+=pixels[i+1];bb+=pixels[i+2];n++;}
   for(let y=by;y<Math.min(by+8,my+mh,ch);y++) for(let x=bx;x<Math.min(bx+8,mx+mw,cw);x++){const i=(y*cw+x)*4;pixels[i]=rr/n;pixels[i+1]=gg/n;pixels[i+2]=bb/n;pixels[i+3]=255;}
  }
  const palette=quantize(pixels,255), indexed=applyPalette(pixels,palette);
  while (palette.length < 256) palette.push([0,0,0]);
  if (priorPixels) for (let i=0;i<indexed.length;i++) {
   const j=i*4;
   if (pixels[j]===priorPixels[j] && pixels[j+1]===priorPixels[j+1] && pixels[j+2]===priorPixels[j+2] && pixels[j+3]===priorPixels[j+3]) indexed[i]=255;
  }
  encoder.writeFrame(indexed,cw,ch,{palette,delay:frame.delay,repeat:0,transparent:!!priorPixels,transparentIndex:255,dispose:1});
  priorPixels=pixels; elapsed+=frame.delay;
 }
 encoder.finish(); fs.writeFileSync(output,encoder.bytes(),{flag:'wx'});
 records.push({file:path.basename(output),source:input,crop,mosaic:masks,frames:frames.length,duration_ms:elapsed,sha256:crypto.createHash('sha256').update(fs.readFileSync(output)).digest('hex')});
 console.log(`${name}: ${frames.length} frames ${elapsed}ms`);
}
fs.writeFileSync(path.join(dest,'manifest.json'),JSON.stringify({kind:'derived-runtime-crops-not-new-recordings',note:'Original historical GIFs remain unchanged. Fixed mosaic zones obscure floating text and may obscure some effects.',records},null,2)+'\n',{flag:'wx'});
