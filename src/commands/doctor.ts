// src/commands/doctor.ts — 环境检查

import { existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { log } from '../utils/log.ts';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SKILLS_DIR = join(__dirname, '..', 'skills');

export async function cmdDoctor() {
  log.bold('\n  🔍 paipai-cli Environment Check\n');

  let ok = true;

  // bun
  try {
    const { execSync } = await import('node:child_process');
    const version = execSync('bun --version', { encoding: 'utf-8' }).trim();
    log.success(`  bun: ${version}`);
  } catch {
    log.error('  bun: not found');
    ok = false;
  }

  // node
  log.success(`  node: ${process.version}`);

  // skills dir
  if (existsSync(SKILLS_DIR)) {
    log.success(`  skills: ${SKILLS_DIR}`);
  } else {
    log.warn(`  skills: not found at ${SKILLS_DIR} (run "paipai skill init <name>" to create one)`);
  }

  // current dir
  log.success(`  cwd: ${process.cwd()}`);

  console.log();
  if (ok) {
    log.success('All checks passed!');
  } else {
    log.error('Some checks failed.');
  }
}
