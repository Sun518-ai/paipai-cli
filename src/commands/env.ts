// src/commands/env.ts — paipai env list / set / unset

import * as p from '@clack/prompts';
import { mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { log } from '../utils/log.ts';
import { readRc, setRcValue, unsetRcValue, getRcPath, KNOWN_GLOBALS } from '../core/rc.ts';

const DIM = '\x1b[2m';
const RESET = '\x1b[0m';

function mask(value: string): string {
  if (value.length <= 6) return '***';
  return value.slice(0, 6) + '***';
}

export async function cmdEnvList() {
  const rcPath = getRcPath();
  const vars = readRc();
  const keys = Object.keys(vars);

  log.bold(`\n  ~/.paipairc (${rcPath})\n`);

  if (keys.length === 0 && KNOWN_GLOBALS.length === 0) {
    log.warn('  No variables configured.');
    console.log();
    return;
  }

  // 1) 显示已设置的变量
  for (const [key, value] of Object.entries(vars)) {
    const known = KNOWN_GLOBALS.find(g => g.name === key);
    const display = known?.sensitive ? mask(value) : value;
    log.success(`  ${key.padEnd(24)} = ${display}`);
  }

  // 2) 检测 process.env 中有但 .paipairc 中没有的已知全局变量
  for (const g of KNOWN_GLOBALS) {
    if (vars[g.name]) continue; // 已在 rc 中
    const envVal = process.env[g.name];
    if (envVal) {
      const display = g.sensitive ? mask(envVal) : envVal;
      log.info(`  ${g.name.padEnd(24)} = ${display}  ${DIM}(from env)${RESET}`);
    }
  }

  // 3) 提示未设置的已知变量
  for (const g of KNOWN_GLOBALS) {
    if (vars[g.name] || process.env[g.name]) continue;
    const hint = g.hint ? ` — ${g.hint}` : '';
    console.log(`  ${DIM}${g.name.padEnd(24)}   (not set)${hint}${RESET}`);
  }

  console.log();
}

export async function cmdEnvSet(key: string, value?: string) {
  let val = value;

  if (val === undefined) {
    // 无值 → 交互输入
    if (!process.stdin.isTTY) {
      log.error(`Usage: paipai env set ${key} <VALUE>`);
      process.exit(1);
    }

    const known = KNOWN_GLOBALS.find(g => g.name === key);
    const placeholder = known?.hint || 'value';

    const input = await p.text({
      message: `Enter value for ${key}:`,
      placeholder,
      validate: (v) => {
        if (!v || !v.trim()) return 'Value cannot be empty';
      },
    });

    if (p.isCancel(input)) {
      p.cancel('Cancelled.');
      process.exit(0);
    }

    val = (input as string).trim();
  }

  setRcValue(key, val);
  process.env[key] = val;

  // When MIRA_CURRENT_USERID is set, initialize the base userdata directory
  if (key === 'MIRA_CURRENT_USERID') {
    const nasDir = join('/opt/tiger/mira_nas/userdata', val);
    const fallbackDir = join(homedir(), '.paipai', 'userdata', val);
    try {
      await mkdir(nasDir, { recursive: true });
      log.info(`Userdata dir initialized: ${nasDir}`);
    } catch {
      try {
        await mkdir(fallbackDir, { recursive: true });
        log.info(`Userdata dir initialized (fallback): ${fallbackDir}`);
      } catch {
        log.warn(`Failed to initialize userdata dir: ${nasDir} and ${fallbackDir}`);
      }
    }
  }

  const known = KNOWN_GLOBALS.find(g => g.name === key);
  const display = known?.sensitive ? mask(val) : val;
  log.success(`${key} = ${display}  (saved to ~/.paipairc)`);
}

export function cmdEnvUnset(key: string) {
  const removed = unsetRcValue(key);
  delete process.env[key];

  if (removed) {
    log.success(`${key} removed from ~/.paipairc`);
  } else {
    log.warn(`${key} was not set in ~/.paipairc`);
  }
}
