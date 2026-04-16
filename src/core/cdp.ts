// src/core/cdp.ts — 浏览器自动授权模块
// 使用已有 Chrome 实例（macOS AppleScript）打开标签页、等待登录、抓取凭据、关闭标签

import { execFile } from 'node:child_process';
import { existsSync } from 'node:fs';

// ─── Chrome Discovery ───

const CHROME_PATHS_DARWIN = [
  '/Applications/Google Chrome.app',
  '/Applications/Google Chrome Canary.app',
  '/Applications/Chromium.app',
];

export function findChromeApp(): string | null {
  if (process.platform !== 'darwin') return null;
  for (const p of CHROME_PATHS_DARWIN) {
    if (existsSync(p)) return p;
  }
  return null;
}

// ─── AppleScript helpers ───

function runAppleScript(script: string): Promise<string> {
  return new Promise((resolve, reject) => {
    execFile('osascript', ['-e', script], { timeout: 15_000 }, (err, stdout, stderr) => {
      if (err) reject(new Error(stderr?.trim() || err.message));
      else resolve(stdout.trim());
    });
  });
}

/** 在已有 Chrome 中打开新标签页并返回 tab index + window id */
async function openTabInChrome(url: string): Promise<{ windowId: string; tabIndex: string }> {
  // 打开新标签并获取其 window id 和 tab index
  const script = `
tell application "Google Chrome"
  activate
  if (count of windows) = 0 then
    make new window
  end if
  tell front window
    set newTab to make new tab with properties {URL:"${url}"}
    set tabIdx to active tab index
    set winId to id
    return (winId as text) & "," & (tabIdx as text)
  end tell
end tell`;
  const result = await runAppleScript(script);
  const [windowId, tabIndex] = result.split(',');
  return { windowId, tabIndex };
}

/** 获取指定标签页的当前 URL */
async function getTabUrl(windowId: string, tabIndex: string): Promise<string> {
  const script = `
tell application "Google Chrome"
  try
    tell window id ${windowId}
      return URL of tab ${tabIndex}
    end tell
  on error
    return "TAB_CLOSED"
  end try
end tell`;
  return await runAppleScript(script);
}

/** 在指定标签页执行 JavaScript 并返回结果 */
async function executeJsInTab(windowId: string, tabIndex: string, js: string): Promise<string> {
  // AppleScript 中需要转义 JS 里的引号和反斜杠
  const escapedJs = js.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
  const script = `
tell application "Google Chrome"
  tell window id ${windowId}
    return execute tab ${tabIndex} javascript "${escapedJs}"
  end tell
end tell`;
  try {
    return await runAppleScript(script);
  } catch (err) {
    const msg = (err as Error).message || '';
    if (msg.includes('AppleScript is turned off') || msg.includes('Allow JavaScript from Apple Events')) {
      throw new Error(
        'Chrome 未开启 AppleScript JS 执行权限。\n'
        + '请在 Chrome 菜单栏中：View → Developer → Allow JavaScript from Apple Events\n'
        + '开启后重新运行即可。',
      );
    }
    throw err;
  }
}

/** 关闭指定标签页 */
async function closeTab(windowId: string, tabIndex: string): Promise<void> {
  const script = `
tell application "Google Chrome"
  try
    tell window id ${windowId}
      close tab ${tabIndex}
    end tell
  end try
end tell`;
  await runAppleScript(script).catch(() => {});
}

// ─── Wait for Auth ───

async function waitForAuth(
  windowId: string,
  tabIndex: string,
  targetDomain: string,
  timeoutMs = 300_000,
  pollMs = 2_000,
): Promise<void> {
  // 等页面初次加载，拍 baseline cookie 快照
  await new Promise(r => setTimeout(r, 4000));

  const baselineCookieStr = await executeJsInTab(windowId, tabIndex, 'document.cookie');
  const baselineNames = new Set(
    baselineCookieStr
      .split(';')
      .map(s => s.trim().split('=')[0])
      .filter(Boolean),
  );

  const start = Date.now();

  while (Date.now() - start < timeoutMs) {
    await new Promise(r => setTimeout(r, pollMs));

    // 检查标签是否被关闭
    const tabUrl = await getTabUrl(windowId, tabIndex);
    if (tabUrl === 'TAB_CLOSED') {
      throw new Error('Browser tab was closed before authorization completed.');
    }

    // 如果页面不在目标域名上（SSO 跳转），继续等
    if (!tabUrl.includes(targetDomain)) {
      continue;
    }

    // 对比 cookie：有新增 → 登录完成
    const currentCookieStr = await executeJsInTab(windowId, tabIndex, 'document.cookie');
    const currentNames = new Set(
      currentCookieStr
        .split(';')
        .map(s => s.trim().split('=')[0])
        .filter(Boolean),
    );

    const hasNew = [...currentNames].some(n => !baselineNames.has(n));
    if (hasNew && currentNames.size > baselineNames.size) {
      return; // 登录完成
    }
  }

  throw new Error('Authorization timeout (5 minutes). Please try again.');
}

// ─── Extract Credentials ───

async function extractCookies(windowId: string, tabIndex: string): Promise<string> {
  return await executeJsInTab(windowId, tabIndex, 'document.cookie');
}

async function extractLocalStorage(windowId: string, tabIndex: string): Promise<string> {
  try {
    return await executeJsInTab(windowId, tabIndex, 'JSON.stringify(localStorage)');
  } catch {
    return '{}';
  }
}

// ─── Public API ───

export async function autoGrabCredentials(loginUrl: string): Promise<{
  cookie: string;
  localStorage: string;
}> {
  const chromeApp = findChromeApp();
  if (!chromeApp) {
    throw new Error(
      'Chrome not found. Please install Google Chrome or use manual paste.\n'
      + 'Expected: /Applications/Google Chrome.app',
    );
  }

  // 在已有 Chrome 中打开新标签页
  const { windowId, tabIndex } = await openTabInChrome(loginUrl);

  try {
    const domain = new URL(loginUrl).hostname;

    // 等待登录完成（cookie 变化检测）
    await waitForAuth(windowId, tabIndex, domain);

    // 提取凭据
    const cookie = await extractCookies(windowId, tabIndex);
    const ls = await extractLocalStorage(windowId, tabIndex);

    return { cookie, localStorage: ls };
  } finally {
    // 关闭标签页
    await closeTab(windowId, tabIndex);
  }
}
