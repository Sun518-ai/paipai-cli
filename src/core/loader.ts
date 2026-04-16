// src/core/loader.ts — Skill 扫描与加载

import { readdir, readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import type { Skill, SkillMeta, SkillArg } from './types.ts';

const SKILL_MD = 'SKILL.md';

function parseSkillMeta(content: string): Partial<SkillMeta> {
  const meta: Partial<SkillMeta> = {
    name: '',
    description: '',
    triggers: [],
    args: [],
    steps: [],
  };

  // 1. YAML frontmatter: name / description / triggers / steps（含 >- 折叠格式）
  const front = content.match(/^---\n([\s\S]*?)\n---\n?/);
  if (front) {
    const frontLines = front[1].split('\n');
    let i = 0;
    let currentListKey: string | null = null;
    let currentList: string[] = [];

    const flushList = () => {
      if (!currentListKey || currentList.length === 0) return;
      if (currentListKey === 'triggers') meta.triggers = currentList;
      else if (currentListKey === 'steps') meta.steps = currentList;
      currentList = [];
      currentListKey = null;
    };

    while (i < frontLines.length) {
      const line = frontLines[i];
      const m = line.match(/^(\w+):\s*(.*)/);

      if (!m) {
        // 可能是 list item continuation（缩进行）
        if (/^\s+-\s+/.test(line) || (/^\s/.test(line) && currentList.length > 0)) {
          // 缩进的 list item
          const itemM = line.match(/^\s+-\s+(.*)/);
          if (itemM) currentList.push(itemM[1].trim());
        }
        i++;
        continue;
      }

      const [, key, firstVal] = m;

      // 遇到新 key，先 flush 前一个 list
      if (['name', 'description'].includes(key)) flushList();

      if (key === 'name') {
        meta.name = firstVal.trim();
      } else if (key === 'description') {
        const folded = firstVal.match(/^([>|]-?)\s*/)?.[1];
        if (folded) {
          const lines = [firstVal.replace(/^[>|]-?\s*/, '')];
          i++;
          while (i < frontLines.length && /^\s+/.test(frontLines[i])) {
            lines.push(frontLines[i].replace(/^\s+/, ''));
            i++;
          }
          meta.description = lines.join(' ').trim();
          continue;
        } else {
          meta.description = firstVal.replace(/^['"]|['"]$/g, '').trim();
        }
      } else if (key === 'triggers' || key === 'steps') {
        // 开始新的 list
        flushList();
        currentListKey = key;
        if (firstVal.trim()) currentList.push(firstVal.replace(/^["']|["']$/g, ''));
        // 检查后续缩进行（inline YAML list）
        while (i + 1 < frontLines.length && /^\s+-\s+/.test(frontLines[i + 1])) {
          i++;
          const itemM = frontLines[i].match(/^\s+-\s+(.*)/);
          if (itemM) currentList.push(itemM[1].trim());
        }
      } else if (key === 'login_url') {
        meta.loginUrl = firstVal.trim();
      } else if (key === 'auth_headers') {
        // Support inline list: auth_headers: [AUTHORIZATION, X-Token]
        // or multi-line list
        const inline = firstVal.match(/^\[(.+)\]$/);
        if (inline) {
          meta.authHeaders = inline[1].split(',').map(s => s.trim()).filter(Boolean);
        } else {
          meta.authHeaders = [];
          if (firstVal.trim()) meta.authHeaders.push(firstVal.trim());
          while (i + 1 < frontLines.length && /^\s+-\s+/.test(frontLines[i + 1])) {
            i++;
            const itemM = frontLines[i].match(/^\s+-\s+(.*)/);
            if (itemM) meta.authHeaders.push(itemM[1].trim());
          }
        }
      } else {
        // args 在 frontmatter 里暂不支持，跳过
      }
      i++;
    }
    flushList();
    content = content.slice(front[0].length);
  }

  // 2. Markdown body
  const lines = content.split('\n');
  let currentSection = '';
  let currentArgs: Partial<SkillArg> = {};

  for (const raw of lines) {
    const line = raw.trim();
    if (!line) continue;

    // 章节标题（如 ## args、## triggers、## 参数说明）
    if (line.startsWith('#')) {
      // flush previous args
      if (currentSection === '## args' && currentArgs.name) {
        meta.args!.push(currentArgs as SkillArg);
        currentArgs = {};
      }
      currentSection = line;
      continue;
    }

    // Markdown 表格行解析（适用于 ## 参数说明 / ## args 区段）
    if ((currentSection === '## 参数说明' || currentSection === '## args') && line.startsWith('|')) {
      // 跳过表头分隔行（如 |------|------|------| ）
      if (/^\|[\s-|]+\|$/.test(line)) continue;
      const cells = line.split('|').map(c => c.trim()).filter(Boolean);
      // 至少需要参数名和说明两列；跳过表头行（第一列为 "参数"）
      if (cells.length >= 2 && !/^参数$/.test(cells[0])) {
        const rawName = cells[0].replace(/`/g, '').replace(/^--/, '');
        const required = cells.length >= 3 ? cells[1] === '是' : false;
        const description = cells.length >= 3 ? cells[2] : cells[1];
        meta.args!.push({
          name: rawName,
          type: 'string',
          required,
          description,
        } as SkillArg);
      }
      continue;
    }

    // - key: value 格式
    if (line.startsWith('- ')) {
      const colonIdx = line.indexOf(':');
      if (colonIdx === -1) continue;
      const key = line.slice(2, colonIdx).trim();
      const value = line.slice(colonIdx + 1).trim().replace(/^["']|["']$/g, '');

      if (currentSection === '## name') {
        meta.name = value;
      } else if (currentSection === '## description') {
        if (['>-', '|-', '>', '|'].some(f => line.includes(f))) continue;
        meta.description = value;
      } else if (currentSection === '## triggers') {
        meta.triggers!.push(value);
      } else if (currentSection === '## steps') {
        meta.steps!.push(value);
      } else if (currentSection === '## args') {
        if (key === 'name') {
          if (currentArgs.name) { meta.args!.push(currentArgs as SkillArg); currentArgs = {}; }
          currentArgs.name = value;
        }
        else if (key === 'type') currentArgs.type = value as SkillArg['type'];
        else if (key === 'required') currentArgs.required = value === 'true';
        else if (key === 'default') currentArgs.default = value;
        else if (key === 'description') currentArgs.description = value;
      }
      continue;
    }

    // 缩进行（如 "  type: string" 在 ## args 区段内）
    if (currentSection === '## args' && line.includes(':')) {
      const colonIdx = line.indexOf(':');
      const key = line.slice(0, colonIdx).trim();
      const value = line.slice(colonIdx + 1).trim().replace(/^["']|["']$/g, '');
      if (key === 'type') currentArgs.type = value as SkillArg['type'];
      else if (key === 'required') currentArgs.required = value === 'true';
      else if (key === 'default') currentArgs.default = value;
      else if (key === 'description') currentArgs.description = value;
      continue;
    }

    // 裸文本行（## name / ## description 区段）
    if ((currentSection === '## name' || currentSection === '## description') && line) {
      const v = line.replace(/^["']|["']$/g, '');
      if (currentSection === '## name') meta.name = v;
      else meta.description = (meta.description || '') + v + ' ';
    }
  }

  // flush last arg
  if (currentSection === '## args' && currentArgs.name) {
    meta.args!.push(currentArgs as SkillArg);
  }

  return meta;
}

function fileExistsSync(path: string): boolean {
  try { return existsSync(path); } catch { return false; }
}

async function loadSkillFromDir(dir: string): Promise<Skill | null> {
  const skillMdPath = join(dir, SKILL_MD);
  const mainShPath = join(dir, 'main.sh');
  const mainTsPath = join(dir, 'main.ts');

  let metaContent = '';
  try {
    metaContent = await readFile(skillMdPath, 'utf-8');
  } catch {
    return null;
  }

  const raw = parseSkillMeta(metaContent);
  const name = raw.name || basename(dir);
  const description = raw.description || '';
  const triggers = raw.triggers || [];
  const args = raw.args || [];
  const steps = raw.steps || [];
  const loginUrl = raw.loginUrl;
  const authHeaders = raw.authHeaders;

  const mainPath = fileExistsSync(mainShPath) ? mainShPath
    : fileExistsSync(mainTsPath) ? mainTsPath : '';

  // 自动收集 step*.sh 文件（fallback）
  let stepPaths = steps.map(s => join(dir, s));
  if (stepPaths.every(p => !fileExistsSync(p))) {
    try {
      const files = await readdir(dir);
      stepPaths = files
        .filter(f => /^step\d+_/.test(f))
        .sort()
        .map(f => join(dir, f));
    } catch {}
  }

  return { name, dir, meta: { name, description, triggers, args, steps, loginUrl, authHeaders }, mainPath, stepPaths };
}

function basename(path: string): string {
  return path.split('/').pop()!;
}

export async function loadAllSkills(skillsDir: string): Promise<Skill[]> {
  const skills: Skill[] = [];
  try {
    const entries = await readdir(skillsDir, { withFileTypes: true });
    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      const skill = await loadSkillFromDir(join(skillsDir, entry.name));
      if (skill) skills.push(skill);
    }
  } catch {}
  return skills;
}
