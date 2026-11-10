import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';
import { deriveProjectIdentityV2 } from '../node_modules/godot-cli/dist/utils/project-identity.js';

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const tools = path.join(projectRoot, '.tools');
const dotnetRoot = path.join(tools, 'dotnet');
const dotnet = path.join(dotnetRoot, 'dotnet.exe');
const editor = process.env.GODOT_BIN ?? process.env.GODOT4_BIN ?? '<PROGRAM_FILES>\\Godot_v4.7.2-stable_mono_win64\\Godot_v4.7.2-stable_mono_win64.exe';
const cli = path.join(projectRoot, 'node_modules', 'godot-cli', 'bin', 'godot-cli.js');
const { port } = deriveProjectIdentityV2(projectRoot);
const [command = 'open', ...args] = process.argv.slice(2);

for (const executable of [dotnet, editor]) {
  if (!existsSync(executable)) {
    console.error(`Missing project-local tool: ${executable}`);
    process.exit(1);
  }
}

// Keep the editor's matching Godot packages in a project-local NuGet feed.
const bundledFeed = path.join(path.dirname(editor), 'GodotSharp', 'Tools', 'nupkgs');
const projectFeed = path.join(tools, 'godot-nupkgs');
mkdirSync(projectFeed, { recursive: true });
if (existsSync(bundledFeed)) {
  for (const name of readdirSync(bundledFeed).filter((name) => name.endsWith('.nupkg'))) {
    const destination = path.join(projectFeed, name);
    if (!existsSync(destination)) copyFileSync(path.join(bundledFeed, name), destination);
  }
}

const env = {
  ...process.env,
  PATH: `${dotnetRoot}${path.delimiter}${process.env.PATH ?? ''}`,
  DOTNET_ROOT: dotnetRoot,
  DOTNET_ROOT_X64: dotnetRoot,
  DOTNET_MULTILEVEL_LOOKUP: '0',
  DOTNET_CLI_HOME: path.join(tools, 'dotnet-home'),
  DOTNET_CLI_TELEMETRY_OPTOUT: '1',
  DOTNET_ADD_GLOBAL_TOOLS_TO_PATH: '0',
  DOTNET_GENERATE_ASPNET_CERTIFICATE: '0',
  DOTNET_NOLOGO: '1',
  NUGET_PACKAGES: path.join(tools, 'nuget', 'packages'),
  NUGET_HTTP_CACHE_PATH: path.join(tools, 'nuget', 'http-cache'),
  NUGET_PLUGINS_CACHE_PATH: path.join(tools, 'nuget', 'plugins-cache'),
  GODOT_BIN: editor,
  GODOT4_BIN: editor,
  GODOT_MCP_CONNECTION_MODE: 'Custom',
  GODOT_MCP_HOST: `http://127.0.0.1:${port}`,
  GODOT_MCP_AUTH_OPTION: 'None',
  GODOT_MCP_START_SERVER: 'true',
};

function run(executable, parameters, cwd = projectRoot) {
  const result = spawnSync(executable, parameters, {
    cwd,
    env,
    stdio: 'inherit',
    windowsHide: true,
  });
  if (result.error) throw result.error;
  return result.status ?? 1;
}

if (command === 'cli') {
  process.exit(run(process.execPath, [cli, ...args]));
} else if (command === 'build') {
  process.exit(run(dotnet, ['build', 'godot-demo.csproj', '--configuration', 'Debug', ...args]));
} else if (command === 'script' || command === 'render-script') {
  if (!args[0]?.startsWith('res://')) {
    console.error('Provide a project script, for example res://tests/test_class_run.gd.');
    process.exit(1);
  }
  process.exit(run(editor, [...(command === 'script' ? ['--headless'] : []), '--path', projectRoot, '--script', ...args]));
} else if (command === 'image-pack-test') {
  // Build a small isolated PCK, then run it without the source PNGs on disk.
  const fixture = mkdtempSync(path.join(tools, 'image-pack-'));
  const packed = path.join(tools, `${path.basename(fixture)}.pck`);
  for (const name of ['project.godot', 'export_presets.cfg', 'smoke.tscn', 'smoke.gd', 'cold.tscn', 'cold.gd']) {
    copyFileSync(path.join(projectRoot, 'tests', 'fixtures', 'image-pack', name), path.join(fixture, name));
  }
  for (const [source, target] of [
    ['scripts/classes/class_image.gd', 'class_image.gd'],
    ['assets/art/mage-leg-revision-v1/characters/mage-idle.png', 'mage-idle.png'],
    ['assets/art/mage-trial-v1/enemies/moon-sentinel.png', 'moon-sentinel.png'],
    ['assets/art/mage-advanced-v1/items/advanced-spells-v2.png', 'advanced-spells-v2.png'],
    ['assets/art/mage-haste-v1/items/wind-prism.png', 'wind-prism.png'],
    ['assets/art/mage-familiar-v1/moon-familiar.png', 'moon-familiar.png'],
    ['assets/art/mage-familiar-upgrade-v1/crowned-moth.png', 'crowned-moth.png'],
    ['assets/art/mage-familiar-wind-v1/wind-moth.png', 'wind-moth.png'],
    ['assets/art/mage-ui-frame-v1/moon-panel.png', 'moon-panel.png'],
    ['assets/art/mage-ui-button-v1/moon-button.png', 'moon-button.png'],
    ['assets/art/mage-seven-battles-v1/enemies/moon-lantern.png', 'moon-lantern.png'],
    ['assets/art/mage-seven-battles-v1/enemies/astral-serpent.png', 'astral-serpent.png'],
  ]) copyFileSync(path.join(projectRoot, source), path.join(fixture, target));
  let status = run(editor, ['--headless', '--path', fixture, 'res://cold.tscn']);
  if (status !== 0) process.exit(status);
  status = run(editor, ['--headless', '--path', fixture, '--editor', '--quit']);
  if (status !== 0) process.exit(status);
  status = run(editor, ['--headless', '--path', fixture, '--export-pack', 'Pack Fixture', packed]);
  if (status !== 0) process.exit(status);
  process.exit(run(editor, ['--headless', '--main-pack', packed], tools));
} else if (command === 'class-capture' || command === 'mage-capture') {
  // Foreground process for bounded native render capture; the caller chooses
  // fresh output paths and --auto-quit. Keep the same local tool environment.
  process.exit(run(editor, ['--path', projectRoot, command === 'mage-capture' ? 'res://scenes/mage_trial.tscn' : 'res://scenes/class_lab.tscn', ...args]));
} else if (command === 'test' || command === 'class-test' || command === 'class-art-test') {
  const tests = command === 'test'
    ? ['test_run_state.gd', 'test_save.gd', 'ui_smoke.gd', 'test_art_v03.gd']
    : command === 'class-test'
      ? ['test_class_run.gd', 'test_class_battle.gd', 'test_class_save.gd', 'class_lab_smoke.gd']
      : ['test_class_art_static.gd', 'test_class_grid_labels.gd', 'test_class_motion.gd', 'test_class_feedback.gd'];
  for (const test of tests) {
    const status = run(editor, ['--headless', '--path', projectRoot, '--script', `res://tests/${test}`]);
    if (status !== 0) process.exit(status);
  }
} else if (command === 'play' || command === 'open' || command === 'class-lab' || command === 'mage-lab' || command === 'mage-campaign' || command === 'art-review') {
  if (command === 'open') {
    const buildStatus = run(dotnet, ['build', 'godot-demo.csproj', '--configuration', 'Debug']);
    if (buildStatus !== 0) process.exit(buildStatus);
  }
  const logDirectory = path.join(tools, 'logs');
  mkdirSync(logDirectory, { recursive: true });
  const logName = command === 'open' ? 'editor.log' : command === 'mage-campaign' ? 'mage-campaign.log' : command === 'mage-lab' ? 'mage.log' : command === 'class-lab' ? 'classes.log' : command === 'art-review' ? 'art-review.log' : 'game.log';
  const sceneArgs = command === 'mage-campaign' ? ['res://scenes/mage_campaign.tscn'] : command === 'mage-lab' ? ['res://scenes/mage_trial.tscn'] : command === 'class-lab' ? ['res://scenes/class_lab.tscn'] : command === 'art-review' ? ['res://scenes/character_review.tscn'] : [];
  const child = spawn(editor, [...(command === 'open' ? ['--editor'] : []), '--path', projectRoot, '--log-file', path.join(logDirectory, logName), ...sceneArgs, ...args], {
    cwd: projectRoot,
    env,
    detached: true,
    stdio: 'ignore',
  });
  child.on('error', (error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
  child.unref();
  console.log(command === 'open' ? `Godot .NET editor started. Local MCP: ${env.GODOT_MCP_HOST}/mcp` : command === 'mage-campaign' ? 'Native Moon Court mage campaign started.' : command === 'mage-lab' ? 'Native Moon Court mage trial started.' : command === 'class-lab' ? 'Native Godot class rules prototype started.' : command === 'art-review' ? 'Native character concept review started (static appearance study, not combat).' : 'Emberpack started.');
} else {
  console.error(`Unknown command: ${command}. Use play, mage-campaign, mage-lab, class-lab, class-capture, art-review, test, class-test, class-art-test, script, render-script, open, build, or cli.`);
  process.exit(1);
}
