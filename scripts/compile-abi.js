#!/usr/bin/env node
/**
 * Quick ABI compiler for interface files.
 * Steps:
 * (1) take interface entry files
 * (2) resolve imports (project + node_modules),
 * (3) feed sources to solc with outputSelection limited to ABIs
 * (4) clean and write JSON outputs.
 * Skip bytecode/metadata generation and avoid Hardhat/foundry pipelines.
 */

const fs = require('fs');
const path = require('path');
const solc = require('solc');

const projectRoot = path.resolve(__dirname, '..');
const outputDir = path.join(projectRoot, 'artifacts', 'abi-interfaces');
const entryFiles = process.argv.slice(2);

if (!entryFiles.length) {
  console.error('Usage: node scripts/interface-abi.js <interface.sol> [...more]');
  process.exit(1);
}

resetOutputDir();
entryFiles.forEach(processInterface);

function processInterface(targetPath) {
  // Per-entry flow: resolve absolute path, gather transitive sources, compile, then emit ABIs.
  const absolutePath = resolvePath(targetPath);
  const sources = collectSources(absolutePath);
  const compilerInput = buildCompilerInput(sources);
  const compiled = compileInput(compilerInput);
  writeAbis(compiled, absolutePath);
}

function resetOutputDir() {
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
    return;
  }

  fs.readdirSync(outputDir).forEach((fileName) => {
    if (fileName.endsWith('.json')) {
      fs.unlinkSync(path.join(outputDir, fileName));
    }
  });
}

function resolvePath(targetPath) {
  const candidate = path.isAbsolute(targetPath) ? targetPath : path.join(projectRoot, targetPath);
  if (fs.existsSync(candidate)) return candidate;
  console.error(`File not found: ${targetPath}`);
  process.exit(1);
}

function collectSources(entry) {
  // Depth-first import walk that loads each file once; keeps source map small for fast solc runs.
  const sources = new Map();
  const pending = [entry];

  while (pending.length) {
    const filePath = pending.pop();
    if (sources.has(filePath)) continue;

    const content = fs.readFileSync(filePath, 'utf8');
    sources.set(filePath, content);

    const imports = findImports(content);
    imports
      .map((importPath) => resolveImport(importPath, filePath))
      .forEach((resolved) => {
        if (sources.has(resolved)) return;
        pending.push(resolved);
      });
  }

  return sources;
}

function findImports(content) {
  const regex = /import\\s+[^'"]*['"]([^'"]+)['"];?/g;
  const imports = [];
  let match = regex.exec(content);

  while (match) {
    imports.push(match[1]);
    match = regex.exec(content);
  }

  return imports;
}

function resolveImport(importPath, fromFile) {
  if (importPath.startsWith('.')) return resolveRelative(importPath, fromFile);

  const contractPath = path.join(projectRoot, importPath);
  if (fs.existsSync(contractPath)) return contractPath;

  const nodeModulesPath = path.join(projectRoot, 'node_modules', importPath);
  if (fs.existsSync(nodeModulesPath)) return nodeModulesPath;

  console.error(`Missing import ${importPath} referenced from ${fromFile}`);
  process.exit(1);
}

function resolveRelative(importPath, fromFile) {
  const baseDir = path.dirname(fromFile);
  const candidate = path.resolve(baseDir, importPath);
  if (fs.existsSync(candidate)) return candidate;

  console.error(`Missing relative import ${importPath} referenced from ${fromFile}`);
  process.exit(1);
}

function buildCompilerInput(sourceMap) {
  const sources = {};
  sourceMap.forEach((content, absPath) => {
    sources[absPath] = { content };
  });

  return {
    language: 'Solidity',
    sources,
    settings: {
      optimizer: { enabled: false, runs: 200 },
      outputSelection: {
        '*': {
          '*': ['abi'],
        },
      },
      metadata: { bytecodeHash: 'none' },
    },
  };
}

function compileInput(compilerInput) {
  const importCallback = (dependencyPath) => {
    if (fs.existsSync(dependencyPath)) return { contents: fs.readFileSync(dependencyPath, 'utf8') };

    const fromRoot = path.join(projectRoot, dependencyPath);
    if (fs.existsSync(fromRoot)) return { contents: fs.readFileSync(fromRoot, 'utf8') };

    const fromNodeModules = path.join(projectRoot, 'node_modules', dependencyPath);
    if (fs.existsSync(fromNodeModules)) return { contents: fs.readFileSync(fromNodeModules, 'utf8') };

    return { error: `Missing import: ${dependencyPath}` };
  };

  const result = JSON.parse(solc.compile(JSON.stringify(compilerInput), { import: importCallback }));
  const errors = (result.errors || []).filter((entry) => entry.severity === 'error');
  if (!errors.length) return result;

  const message = errors.map((entry) => entry.formattedMessage || entry.message).join('\\n');
  console.error(message);
  process.exit(1);
}

function writeAbis(compiled, entryPath) {
  const compiledFile = compiled.contracts[entryPath];

  if (!compiledFile) {
    console.error(`No compiled output for ${entryPath}`);
    process.exit(1);
  }

  Object.entries(compiledFile).forEach(([contractName, artifact]) => {
    const abiPath = path.join(outputDir, `${contractName}.json`);
    fs.writeFileSync(abiPath, JSON.stringify(artifact.abi, null, 2));
    console.log(`Wrote ABI: ${abiPath}`);
  });
}
