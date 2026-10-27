// Convert actual Godot Movie Maker PNG frames into a silent blog animation.
// Optional encoders stay under .tools/media, outside game dependencies.
const fs = require('node:fs');
const path = require('node:path');
const { createRequire } = require('node:module');
const root = path.resolve(__dirname, '..');
const mediaRequire = createRequire(path.join(root, '.tools/media/package.json'));
const { PNG } = mediaRequire('pngjs');
const { GIFEncoder, quantize, applyPalette } = mediaRequire('gifenc');
const [inputDirectory, outputFile, ...options] = process.argv.slice(2);
if (!inputDirectory || !outputFile) {
  console.error('Usage: node scripts/capture-demo-gif.cjs <movie-frame-directory> <output.gif> [--fps=16 --step=2 --scale=2 --start=0 --frames=all --crop=x,y,width,height --delta]');
  process.exit(1);
}
const inputs = fs.readdirSync(inputDirectory).filter((name) => /^frame\d+\.png$/.test(name)).sort();
if (!inputs.length) throw new Error('No Godot frame PNGs found');
const settings = { fps: 16, step: 2, scale: 2, start: 0, frames: inputs.length };
let crop = null;
let deltaFrames = false;
for (const option of options) {
  if (option === '--delta') {
    deltaFrames = true;
    continue;
  }
  const rectangle = /^--crop=(\d+),(\d+),(\d+),(\d+)$/.exec(option);
  if (rectangle) {
    crop = rectangle.slice(1).map(Number);
    continue;
  }
  const match = /^--(fps|step|scale|start|frames)=(\d+)$/.exec(option);
  if (!match) throw new Error(`Invalid option: ${option}`);
  settings[match[1]] = Number(match[2]);
}
if (settings.fps < 1 || settings.fps > 100 || settings.step < 1 || settings.scale < 1 || settings.frames < 1 || settings.start >= inputs.length) throw new Error('Invalid capture range/rate');
if (fs.existsSync(outputFile)) throw new Error('Refusing to overwrite existing GIF evidence');
const end = Math.min(inputs.length, settings.start + settings.frames);
const gif = GIFEncoder();
let frameCount = 0;
let outputWidth = 0;
let outputHeight = 0;
let previousPixels = null;
for (let index = settings.start; index < end; index += settings.step) {
  const frame = PNG.sync.read(fs.readFileSync(path.join(inputDirectory, inputs[index])));
  const [left, top, cropWidth, cropHeight] = crop ?? [0, 0, frame.width, frame.height];
  if (cropWidth < 1 || cropHeight < 1 || left + cropWidth > frame.width || top + cropHeight > frame.height || cropWidth < settings.scale || cropHeight < settings.scale) throw new Error('Crop is outside source frame or smaller than output scale');
  const width = Math.floor(cropWidth / settings.scale);
  const height = Math.floor(cropHeight / settings.scale);
  if (frameCount && (width !== outputWidth || height !== outputHeight)) throw new Error('Frame sizes differ');
  outputWidth = width;
  outputHeight = height;
  const pixels = new Uint8Array(width * height * 4);
  // Integer nearest-neighbor sampling of actual runtime frames.
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const source = ((top + y * settings.scale) * frame.width + left + x * settings.scale) * 4;
      const target = (y * width + x) * 4;
      pixels.set(frame.data.subarray(source, source + 4), target);
    }
  }
  const palette = quantize(pixels, deltaFrames ? 255 : 256);
  const indexed = applyPalette(pixels, palette);
  if (deltaFrames) {
    // Transparent index 255 preserves the previous composited canvas. Reserve
    // it even when the quantizer returned fewer colors; never erase an actor.
    while (palette.length < 256) palette.push([0, 0, 0]);
    if (previousPixels) {
      for (let pixel = 0; pixel < indexed.length; pixel++) {
        const byte = pixel * 4;
        if (pixels[byte] === previousPixels[byte] && pixels[byte + 1] === previousPixels[byte + 1] && pixels[byte + 2] === previousPixels[byte + 2] && pixels[byte + 3] === previousPixels[byte + 3]) indexed[pixel] = 255;
      }
    }
    previousPixels = pixels;
  }
  // Distribute rounding over time; GIF delays have 10ms resolution.
  const tick = 100 * settings.step / settings.fps;
  const delay = (Math.round((frameCount + 1) * tick) - Math.round(frameCount * tick)) * 10;
  gif.writeFrame(indexed, width, height, { palette, delay, repeat: 0, ...(deltaFrames ? { transparent: frameCount > 0, transparentIndex: 255, dispose: 1 } : {}) });
  frameCount++;
}
gif.finish();
fs.mkdirSync(path.dirname(path.resolve(outputFile)), { recursive: true });
fs.writeFileSync(outputFile, gif.bytes(), { flag: 'wx' });
console.log(JSON.stringify({ outputFile, sourceFrames: inputs.length, sourceStart: settings.start, sourceEndExclusive: end, sourceFps: settings.fps, frameStep: settings.step, crop, scale: settings.scale, deltaFrames, frames: frameCount, width: outputWidth, height: outputHeight, bytes: fs.statSync(outputFile).size, audio: false }));
