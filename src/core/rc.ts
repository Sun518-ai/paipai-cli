// src/core/rc.ts — ~/.paipairc 读写工具

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';

export interface KnownVar {
  name: string;
  sensitive: boolean;
  hint: string | null;
}

/** 已知全局环境变量白名单 */
export const KNOWN_GLOBALS: KnownVar[] = [
  { name: 'MIRA_CURRENT_USERID', sensitive: false, hint: 'Mira 用户 ID（数字），可在 Mira 个人主页获取' },
  { name: 'COOKIE',              sensitive: true,  hint: null },
  { name: 'X_RISK_CSRF_TOKEN',   sensitive: true,  hint: 'X-Risk-Csrf-Token，从浏览器 DevTools 获取' },
  { name: 'AUTHORIZATION',       sensitive: true,  hint: 'Authorization 请求头，从浏览器 DevTools 获取' },
];

export function getRcPath(): string {
  return join(homedir(), '.paipairc');
}

/** 原始行结构，用于保留注释和空行 */
interface RcLine {
  raw: string;
  key?: string;
  value?: string;
}

function parseLines(content: string): RcLine[] {
  return content.split('\n').map(raw => {
    const line = raw.trim();
    if (!line || line.startsWith('#')) return { raw };
    const eq = line.indexOf('=');
    if (eq === -1) return { raw };
    const key = line.slice(0, eq).trim();
    const value = line.slice(eq + 1).trim().replace(/^["']|["']$/g, '');
    return { raw, key, value };
  });
}

/** 读取 ~/.paipairc，返回 KV 对象 */
export function readRc(): Record<string, string> {
  const rcPath = getRcPath();
  if (!existsSync(rcPath)) return {};
  const lines = parseLines(readFileSync(rcPath, 'utf-8'));
  const result: Record<string, string> = {};
  for (const l of lines) {
    if (l.key && l.value !== undefined) {
      result[l.key] = l.value;
    }
  }
  return result;
}

/** 设置一个 key=value，保留已有注释和其他行 */
export function setRcValue(key: string, value: string): void {
  const rcPath = getRcPath();
  let content = '';
  if (existsSync(rcPath)) {
    content = readFileSync(rcPath, 'utf-8');
  }

  const lines = parseLines(content);
  let found = false;

  const output: string[] = [];
  for (const l of lines) {
    if (l.key === key) {
      output.push(`${key}=${value}`);
      found = true;
    } else {
      output.push(l.raw);
    }
  }

  if (!found) {
    // 去掉末尾空行后追加
    while (output.length > 0 && output[output.length - 1].trim() === '') {
      output.pop();
    }
    output.push(`${key}=${value}`);
  }

  writeFileSync(rcPath, output.join('\n') + '\n', 'utf-8');
}

/** 从 ~/.paipairc 中删除指定 key */
export function unsetRcValue(key: string): boolean {
  const rcPath = getRcPath();
  if (!existsSync(rcPath)) return false;

  const content = readFileSync(rcPath, 'utf-8');
  const lines = parseLines(content);

  let found = false;
  const output: string[] = [];
  for (const l of lines) {
    if (l.key === key) {
      found = true;
    } else {
      output.push(l.raw);
    }
  }

  if (found) {
    writeFileSync(rcPath, output.join('\n') + '\n', 'utf-8');
  }
  return found;
}

/**
 * 加载 ~/.paipairc 并注入 process.env（不覆盖已有值）。
 * 替代 index.ts 中原来的 loadRc()。
 */
export function loadRcToEnv(): void {
  const vars = readRc();
  for (const [key, val] of Object.entries(vars)) {
    if (key && val && !process.env[key]) {
      process.env[key] = val;
    }
  }
}
