// src/commands/doctor.ts — 环境检查

import { existsSync } from 'node:fs';
import { log } from '../utils/log.ts';

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
  const skillsDir = './skills';
  if (existsSync(skillsDir)) {
    log.success(`  ./skills: exists`);
  } else {
    log.warn(`  ./skills: not found (run "paipai skill init <name>" to create one)`);
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
