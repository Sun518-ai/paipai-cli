// src/core/loader.ts — Skill 扫描与加载

import { readdir, readFile } from 'node:fs/promises';
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

  // 1. 从 YAML frontmatter 提取 name / description
  const front = content.match(/^---\n([\s\S]*?)\n---\n?/);
  if (front) {
    const frontLines = front[1].split('\n');
    let i = 0;
    while (i < frontLines.length) {
      const nameMatch = frontLines[i].match(/^(\w+):\s*(.*)/);
      if (!nameMatch) { i++; continue; }
      const [, key, firstVal] = nameMatch;

      if (key === 'name') {
        meta.name = firstVal.trim();
      } else if (key === 'description') {
        // 处理 YAML 折叠标量 >-  |-  >  |
        const folded = firstVal.match(/^([>|]-?)\s*/)?.[1];
        if (folded) {
          // 收集后续缩进行
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
      }
      i++;
    }
    content = content.slice(front[0].length);
  }

  // 2. 解析 Markdown body（## sections + - key: value）
  const lines = content.split('\n');
  let currentSection = '';
  let currentArgs: Partial<SkillArg> = {};

  for (const raw of lines) {
    const line = raw.trim();
    if (!line) continue;

    // 章节标题
    if (line.startsWith('#')) {
      if (currentSection === '## args' && currentArgs.name) {
        meta.args!.push(currentArgs as SkillArg);
        currentArgs = {};
      }
      currentSection = line;
      continue;
    }

    if (line.startsWith('- ')) {
      const colonIdx = line.indexOf(':');
      if (colonIdx === -1) continue;

      const key = line.slice(2, colonIdx).trim();
      const value = line.slice(colonIdx + 1).trim().replace(/^["']|["']$/g, '');

      if (currentSection === '## name') {
        meta.name = value;
      } else if (currentSection === '## description') {
        // 跳过 YAML 折叠标记行（如 description: >-）
        if (['>-', '|-', '>', '|'].some(f => line.includes(f))) continue;
        meta.description = value;
      } else if (currentSection === '## triggers') {
        meta.triggers!.push(value);
      } else if (currentSection === '## steps') {
        meta.steps!.push(value);
      } else if (currentSection === '## args') {
        if (key === 'name') currentArgs.name = value;
        else if (key === 'type') currentArgs.type = value as SkillArg['type'];
        else if (key === 'required') currentArgs.required = value === 'true';
        else if (key === 'default') currentArgs.default = value;
        else if (key === 'description') currentArgs.description = value;
      }
    } else if (currentSection === '## description' && line) {
      // 裸文本行（无 - 前缀），YAML 多行折叠继续累积
      const v = line.replace(/^["']|["']$/g, '');
      meta.description = (meta.description || '') + v + ' ';
    }
  }

  // flush last arg
  if (currentSection === '## args' && currentArgs.name) {
    meta.args!.push(currentArgs as SkillArg);
  }

  return meta;
}

function fileExistsSync(path: string): boolean {
  try { return require('node:fs').existsSync(path); } catch { return false; }
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

  return { name, dir, meta: { name, description, triggers, args, steps }, mainPath, stepPaths };
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
