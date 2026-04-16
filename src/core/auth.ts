// src/core/auth.ts — TUI 授权交互模块

import * as p from '@clack/prompts';
import { readFile, writeFile, mkdir, access } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { homedir } from 'node:os';
import { constants } from 'node:fs';
import { exec } from 'node:child_process';
import type { Skill } from './types.ts';
import { autoGrabCredentials } from './cdp.ts';

const MIRA_NAS_USERDATA = '/opt/tiger/mira_nas/userdata';
const LOCAL_FALLBACK_USERDATA = join(homedir(), '.paipai', 'userdata');

/**
 * 获取用户数据根目录：
 * - Mira 环境: /opt/tiger/mira_nas/userdata/$USERID（NAS 不可写时 fallback 到 ~/.paipai/userdata/$USERID）
 * - 本地: <skillDir>/.userdata
 */
export async function getUserdataBaseDir(skill: Skill): Promise<string> {
  const userId = process.env.MIRA_CURRENT_USERID;
  if (userId) {
    const nasDir = join(MIRA_NAS_USERDATA, userId);
    try {
      await access(nasDir, constants.W_OK);
      return nasDir;
    } catch {
      return join(LOCAL_FALLBACK_USERDATA, userId);
    }
  }
  return join(skill.dir, '.userdata');
}

/**
 * 获取 skill 专属的用户数据目录：
 * - Mira 环境: /opt/tiger/mira_nas/userdata/$USERID/<skill-name>
 * - 本地: <skillDir>/.userdata/<skill-name>
 */
export async function getSkillUserdataDir(skill: Skill): Promise<string> {
  return join(await getUserdataBaseDir(skill), skill.name);
}

/**
 * 初始化 skill 的用户数据目录（递归创建）。
 * 返回创建好的 skill userdata 目录路径。
 */
export async function ensureSkillUserdataDir(skill: Skill): Promise<string> {
  const dir = await getSkillUserdataDir(skill);
  await mkdir(dir, { recursive: true });
  return dir;
}

/**
 * Cookie 持久化路径，与 main.sh 保持一致：
 * - Mira 环境: /opt/tiger/mira_nas/userdata/$USERID/<skill-name>/.cookie
 * - 本地: <skillDir>/.userdata/<skill-name>/.cookie
 */
export async function getCookiePath(skill: Skill): Promise<string> {
  return join(await getSkillUserdataDir(skill), '.cookie');
}

async function loadCookie(cookiePath: string): Promise<string | null> {
  try {
    const content = (await readFile(cookiePath, 'utf-8')).trim();
    return content || null;
  } catch {
    return null;
  }
}

async function saveCookie(cookiePath: string, cookie: string): Promise<void> {
  await mkdir(dirname(cookiePath), { recursive: true });
  await writeFile(cookiePath, cookie, 'utf-8');
}

/**
 * localStorage 持久化路径：
 * - <skillUserdataDir>/.localstorage
 */
export async function getLocalStoragePath(skill: Skill): Promise<string> {
  return join(await getSkillUserdataDir(skill), '.localstorage');
}

async function loadLocalStorage(lsPath: string): Promise<string | null> {
  try {
    const content = (await readFile(lsPath, 'utf-8')).trim();
    return content || null;
  } catch {
    return null;
  }
}

async function saveLocalStorage(lsPath: string, data: string): Promise<void> {
  await mkdir(dirname(lsPath), { recursive: true });
  await writeFile(lsPath, data, 'utf-8');
}

function extractDomain(url: string): string {
  try {
    return new URL(url).hostname;
  } catch {
    return url;
  }
}

function openBrowser(url: string): void {
  const cmd = process.platform === 'darwin' ? 'open'
    : process.platform === 'win32' ? 'start' : 'xdg-open';
  exec(`${cmd} "${url}"`);
}

/**
 * Auth headers 持久化路径：
 * - <skillUserdataDir>/.auth_headers (JSON)
 */
async function getAuthHeadersPath(skill: Skill): Promise<string> {
  return join(await getSkillUserdataDir(skill), '.auth_headers');
}

async function loadAuthHeaders(filePath: string): Promise<Record<string, string>> {
  try {
    const content = (await readFile(filePath, 'utf-8')).trim();
    if (!content) return {};
    return JSON.parse(content);
  } catch {
    return {};
  }
}

async function saveAuthHeaders(filePath: string, headers: Record<string, string>): Promise<void> {
  await mkdir(dirname(filePath), { recursive: true });
  await writeFile(filePath, JSON.stringify(headers, null, 2), 'utf-8');
}

/**
 * 检查 skill 是否需要鉴权，若 Cookie 缺失则启动 TUI 交互。
 * 返回 envOverrides 供 runner 注入。
 */
export async function ensureAuth(skill: Skill): Promise<Record<string, string>> {
  const { loginUrl } = skill.meta;
  if (!loginUrl) return {};

  const cookiePath = await getCookiePath(skill);

  // 环境变量已有 Cookie → 持久化并返回
  if (process.env.COOKIE) {
    await saveCookie(cookiePath, process.env.COOKIE).catch(() => {});
    const envs: Record<string, string> = { COOKIE: process.env.COOKIE };
    const lsPath = await getLocalStoragePath(skill);
    const ls = await loadLocalStorage(lsPath);
    if (ls) {
      envs.LOCAL_STORAGE = ls;
      envs.LOCAL_STORAGE_FILE = lsPath;
    }
    return envs;
  }

  // 磁盘已有 Cookie → 直接返回
  const existing = await loadCookie(cookiePath);
  if (existing) {
    const envs: Record<string, string> = { COOKIE: existing };
    const lsPath = await getLocalStoragePath(skill);
    const ls = await loadLocalStorage(lsPath);
    if (ls) {
      envs.LOCAL_STORAGE = ls;
      envs.LOCAL_STORAGE_FILE = lsPath;
    }
    return envs;
  }

  // 非 TTY → 无法交互，打印提示后退出
  if (!process.stdin.isTTY) {
    console.error(`Skill "${skill.name}" requires a Cookie for ${extractDomain(loginUrl)}.`);
    console.error(`Set COOKIE env var: COOKIE=<value> paipai run ${skill.name}`);
    process.exit(1);
  }

  // ─── TUI 交互 ───
  const domain = extractDomain(loginUrl);

  p.intro(`Skill "${skill.name}" requires authorization`);

  p.note(
    `This skill needs a Cookie for ${domain}.\nCookie will be saved to: ${cookiePath}`,
    'Authorization Required',
  );

  const action = await p.select({
    message: 'How would you like to authorize?',
    options: [
      { label: 'Auto: open browser & grab cookie automatically', value: 'auto' as const },
      { label: 'Open browser to authorize, then paste cookie', value: 'browser' as const },
      { label: 'Paste cookie manually', value: 'paste' as const },
    ],
  });

  if (p.isCancel(action)) {
    p.cancel('Authorization cancelled.');
    process.exit(0);
  }

  // ─── Auto CDP 模式 ───
  if (action === 'auto') {
    const s = p.spinner();
    s.start('Launching Chrome & waiting for login...');

    try {
      const { cookie: cookieStr, localStorage: lsJson } = await autoGrabCredentials(loginUrl);
      s.stop('Credentials captured!');

      // 保存 cookie
      try {
        await saveCookie(cookiePath, cookieStr);
        p.log.success('Cookie saved successfully!');
      } catch {
        p.log.warn('Cookie save failed (will use for this session only)');
      }

      // 保存 localStorage
      const lsPath = await getLocalStoragePath(skill);
      try {
        await saveLocalStorage(lsPath, lsJson);
        p.log.success('localStorage saved successfully!');
      } catch {
        p.log.warn('localStorage save failed');
      }

      p.outro('Authorization complete! Running skill...');

      return {
        COOKIE: cookieStr,
        LOCAL_STORAGE: lsJson,
        LOCAL_STORAGE_FILE: lsPath,
      };
    } catch (err) {
      s.stop('Auto-grab failed');
      p.log.error((err as Error).message);
      p.log.info('Falling back to manual paste...');
      // Fall through to paste flow below
    }
  }

  if (action === 'browser') {
    openBrowser(loginUrl);
    p.log.info(`Browser opened: ${loginUrl}`);
    p.log.info('After logging in, open DevTools (F12) → Application → Cookies');
    p.log.info('Copy all cookies as "key1=value1; key2=value2; ..."');
  }

  const cookie = await p.text({
    message: 'Paste your Cookie:',
    placeholder: 'key1=value1; key2=value2; ...',
    validate: (value) => {
      if (!value || !value.trim()) return 'Cookie cannot be empty';
    },
  });

  if (p.isCancel(cookie)) {
    p.cancel('Authorization cancelled.');
    process.exit(0);
  }

  const cookieStr = (cookie as string).trim();

  // 保存
  try {
    await saveCookie(cookiePath, cookieStr);
    p.log.success('Cookie saved successfully!');
  } catch {
    p.log.warn('Cookie save failed (will use for this session only)');
  }

  p.outro('Authorization complete! Running skill...');

  return { COOKIE: cookieStr };
}

/**
 * 确保 skill 所需的额外 auth headers（如 AUTHORIZATION）已就绪。
 * 检查顺序：环境变量 → 磁盘持久化 → TUI 交互。
 * 返回的 envOverrides 会被 merge 到 runner 环境中。
 */
export async function ensureAuthHeaders(skill: Skill, envOverrides: Record<string, string>): Promise<void> {
  const { authHeaders } = skill.meta;
  if (!authHeaders || authHeaders.length === 0) return;

  const headersPath = await getAuthHeadersPath(skill);
  const persisted = await loadAuthHeaders(headersPath);
  let dirty = false;

  for (const header of authHeaders) {
    // 1. 环境变量已有 → 持久化并使用
    if (process.env[header]) {
      envOverrides[header] = process.env[header]!;
      if (persisted[header] !== process.env[header]) {
        persisted[header] = process.env[header]!;
        dirty = true;
      }
      continue;
    }

    // 2. envOverrides 已有（例如 Mira 插件注入）→ 跳过
    if (envOverrides[header]) continue;

    // 3. 磁盘已有 → 使用
    if (persisted[header]) {
      envOverrides[header] = persisted[header];
      continue;
    }

    // 4. TTY 交互
    if (!process.stdin.isTTY) {
      // 非 TTY 不交互，跳过（main.sh 会用空值 fallback）
      continue;
    }

    const value = await p.text({
      message: `Paste your ${header}:`,
      placeholder: `Bearer eyJhbGciOi...`,
      validate: (v) => {
        if (!v || !v.trim()) return `${header} cannot be empty`;
      },
    });

    if (p.isCancel(value)) {
      // 用户取消，跳过该 header
      continue;
    }

    const val = (value as string).trim();
    envOverrides[header] = val;
    persisted[header] = val;
    dirty = true;
  }

  if (dirty) {
    try {
      await saveAuthHeaders(headersPath, persisted);
    } catch {
      // ignore save failure
    }
  }
}
