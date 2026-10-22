// Convert actual Godot Movie Maker PNG frames into a silent blog animation.
// Optional encoders stay under .tools/media, outside game dependencies.
const fs = require('node:fs');
const path = require('node:path');
const { createRequire } = require('node:module');
const root = path.resolve(__dirname, '..');
const mediaRequire = createRequire(path.join(root, '.tools/media/package.json'));
const { PNG } = mediaRequire('pngjs');
const { GIFEncoder, quantize, applyPalette } = mediaRequire('gifenc');
const [inputDirectory, outputFile] = process.argv.slice(2);
if (!inputDirectory || !outputFile) {
  console.error('Usage: node scripts/capture-demo-gif.cjs <movie-frame-directory> <output.gif>');
  process.exit(1);
}
const inputs = fs.readdirSync(inputDirectory).filter((name) => /^frame\d+\.png$/.test(name)).sort();
if (!inputs.length) throw new Error('No Godot frame PNGs found');
const gif = GIFEncoder();
let frameCount = 0;
let outputWidth = 0;
let outputHeight = 0;
for (let index = 0; index < inputs.length; index += 2) {
  const frame = PNG.sync.read(fs.readFileSync(path.join(inputDirectory, inputs[index])));
  const width = Math.floor(frame.width / 2);
  const height = Math.floor(frame.height / 2);
  if (frameCount && (width !== outputWidth || height !== outputHeight)) throw new Error('Frame sizes differ');
  outputWidth = width;
  outputHeight = height;
  const pixels = new Uint8Array(width * height * 4);
  // Exactly 1/2 nearest-neighbor sampling, preserving the source pixel grid.
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const source = ((y * 2) * frame.width + x * 2) * 4;
      const target = (y * width + x) * 4;
      pixels.set(frame.data.subarray(source, source + 4), target);
    }
  }
  const palette = quantize(pixels, 256);
  const indexed = applyPalette(pixels, palette);
  // GIF time units are 10 ms: alternate 120/130 for an average of 8 FPS.
  gif.writeFrame(indexed, width, height, { palette, delay: frameCount % 2 ? 130 : 120, repeat: 0 });
  frameCount++;
}
gif.finish();
fs.mkdirSync(path.dirname(path.resolve(outputFile)), { recursive: true });
fs.writeFileSync(outputFile, gif.bytes());
console.log(JSON.stringify({ outputFile, sourceFrames: inputs.length, frames: frameCount, width: outputWidth, height: outputHeight, bytes: fs.statSync(outputFile).size, audio: false }));
