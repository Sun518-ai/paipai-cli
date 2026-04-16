// src/commands/skill.ts — paipai skill list / run / init / remove

import { join, relative, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { existsSync } from 'node:fs';
import { mkdir, writeFile, readdir, rm } from 'node:fs/promises';
import { loadAllSkills } from '../core/loader.ts';
import { runSkill, runStep } from '../core/runner.ts';
import { ensureAuth, ensureAuthHeaders, getCookiePath, getLocalStoragePath, ensureSkillUserdataDir, getUserdataBaseDir } from '../core/auth.ts';
import { log } from '../utils/log.ts';
import type { Skill } from '../core/types.ts';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SKILLS_DIR = join(__dirname, '..', 'skills');

export async function cmdSkillList() {
  const skills = await loadAllSkills(SKILLS_DIR);
  if (skills.length === 0) {
    log.warn('No skills found in ./skills/');
    return;
  }

  log.bold(`\n  🧩 Available Skills (${skills.length})\n`);
  for (const s of skills) {
    const trigger = (s.meta.triggers[0] || `paipai run ${s.name}`);
    // 截断过长描述，保持格式整洁
    const desc = (s.meta.description || '').replace(/\s+/g, ' ').substring(0, 60);
    process.stdout.write(`  ${s.name.padEnd(20)} ${desc}`);
    if (desc.length === 60) process.stdout.write('…');
    process.stdout.write('\n');
    log.debug(`    triggers: ${s.meta.triggers.join(', ')} | steps: ${s.stepPaths.length}`);
  }
  console.log();
}

function printSkillHelp(skill: Skill) {
  const desc = skill.meta.description || '(no description)';
  console.log(`\n  🧩 ${skill.name} — ${desc}\n`);
  console.log(`  Usage: paipai run ${skill.name} [options]\n`);

  if (skill.meta.args.length === 0) {
    console.log('  No arguments.\n');
    return;
  }

  console.log('  Options:\n');
  for (const a of skill.meta.args) {
    const flag = `--${a.name}`;
    const req = a.required ? '(required)' : '(optional)';
    const def = a.default !== undefined ? `[default: ${a.default}]` : '';
    const descPart = a.description || '';
    console.log(`    ${flag.padEnd(20)} ${a.type.padEnd(10)} ${req} ${def}`);
    if (descPart) {
      console.log(`${''.padEnd(24)} ${descPart}`);
    }
  }
  console.log();
}

export async function cmdSkillRun(skillName: string, rawArgs: string[]) {
  const skills = await loadAllSkills(SKILLS_DIR);
  const skill = skills.find(s => s.name === skillName);
  if (!skill) {
    log.error(`Skill "${skillName}" not found. Run "paipai skill list" to see available skills.`);
    process.exit(1);
  }

  // --help / -h: 打印 skill 参数列表
  if (rawArgs.includes('--help') || rawArgs.includes('-h')) {
    printSkillHelp(skill);
    return;
  }

  // 解析参数（支持 --key value 和 --key=value 两种格式）
  const args: Record<string, string | number | boolean> = {};
  const positionalArgs: string[] = [];

  for (let i = 0; i < rawArgs.length; i++) {
    const arg = rawArgs[i];
    if (!arg.startsWith('--')) {
      positionalArgs.push(arg);
      continue;
    }

    // --key=value 格式
    if (arg.includes('=')) {
      const [key, ...rest] = arg.slice(2).split('=');
      const val = rest.join('=');
      const matchedArg = skill.meta.args.find(a => a.name === key);
      args[key] = matchedArg?.type === 'number' ? Number(val) : val;
      continue;
    }

    // --key value 格式
    const key = arg.slice(2);
    const matchedArg = skill.meta.args.find(a => a.name === key);
    const next = rawArgs[i + 1];
    if (next && !next.startsWith('--')) {
      args[key] = matchedArg?.type === 'number' ? Number(next) : next;
      i++; // skip next
    } else {
      args[key] = true;
    }
  }

  // 必填参数校验
  for (const argDef of skill.meta.args) {
    const isRequired = argDef.required === true;
    const hasDefault = argDef.default !== undefined;
    const wasProvided = args[argDef.name] !== undefined;
    if (isRequired && !hasDefault && !wasProvided) {
      log.error(`Missing required argument: --${argDef.name}`);
      if (argDef.description) {
        log.info(`  说明: ${argDef.description}`);
      }
      process.exit(1);
    }
    // 应用默认值
    if (!wasProvided && hasDefault) {
      args[argDef.name] = argDef.default;
    }
  }

  log.info(`Running skill: ${skill.name}`);
  log.debug(`Args: ${JSON.stringify(args)}`);

  // Authorization check (TUI flow if needed)
  const envOverrides = await ensureAuth(skill);

  // Auth headers check (e.g. AUTHORIZATION)
  await ensureAuthHeaders(skill, envOverrides);

  // Initialize userdata directories and pass as env vars
  try {
    const userdataBaseDir = await getUserdataBaseDir(skill);
    const userdataDir = await ensureSkillUserdataDir(skill);
    const cookiePath = await getCookiePath(skill);

    envOverrides.USERDATA_DIR = userdataBaseDir;
    envOverrides.MIRA_USERDATA_DIR = userdataBaseDir;
    envOverrides.SKILL_USERDATA_DIR = userdataDir;
    envOverrides.COOKIE_FILE = cookiePath;
    const lsPath = await getLocalStoragePath(skill);
    envOverrides.LOCAL_STORAGE_FILE = lsPath;
    log.debug(`Userdata base: ${userdataBaseDir}`);
    log.debug(`Skill userdata: ${userdataDir}`);
    log.debug(`Cookie file: ${cookiePath}`);
  } catch (e) {
    log.warn(`Failed to initialize userdata dir: ${(e as Error).message}`);
  }

  const ctx = { skill, args, positionalArgs, skillDir: skill.dir };

  if (skill.stepPaths.length > 0 && !skill.mainPath) {
    // 无 main.sh，按顺序执行各 step
    for (const step of skill.stepPaths) {
      const stepName = relative(skill.dir, step);
      log.info(`  → ${stepName}`);
      const code = await runStep(step, ctx, envOverrides);
      if (code !== 0) {
        log.error(`Step ${stepName} exited with code ${code}`);
        process.exit(code);
      }
    }
  } else {
    // 执行 main.sh
    const code = await runSkill(ctx, envOverrides);
    process.exit(code);
  }
}

export async function cmdSkillInit(name: string) {
  const safeName = name.toLowerCase().replace(/[^a-z0-9-]/g, '-');
  const skillDir = join(SKILLS_DIR, safeName);

  try {
    await mkdir(skillDir, { recursive: true });
  } catch (e) {
    log.error(`Failed to create directory: ${skillDir}`);
    process.exit(1);
  }

  const SKILL_MD = `# SKILL.md

## name
${safeName}

## description
TODO: 描述这个技能的作用

## triggers
- paipai run ${safeName}

## args
- name: target
  type: string
  required: false
  default: world
  description: 目标对象

## steps
- step1_hello.sh
`;

  const MAIN_SH = `#!/bin/bash
set -e

SKILL_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"

echo "Skill: ${safeName}"
bash "\$SKILL_DIR/step1_hello.sh"
`;

  const STEP1 = `#!/bin/bash
# step1_hello.sh

TARGET="\${SKILL_ARG_TARGET:-world}"
echo "Hello, \$TARGET!"
`;

  await writeFile(join(skillDir, 'SKILL.md'), SKILL_MD);
  await writeFile(join(skillDir, 'main.sh'), MAIN_SH);
  await writeFile(join(skillDir, 'step1_hello.sh'), STEP1);

  log.success(`Skill "${safeName}" created at ${skillDir}`);
  log.info('Edit SKILL.md to configure metadata, then run:');
  log.info(`  paipai run ${safeName}`);
}

export async function cmdSkillRemove(name: string) {
  const skillDir = join(SKILLS_DIR, name);
  const skills = await loadAllSkills(SKILLS_DIR);
  const skill = skills.find(s => s.name === name);
  if (!skill) {
    log.error(`Skill "${name}" not found. Run "paipai skill list" to see available skills.`);
    process.exit(1);
  }

  try {
    await rm(skillDir, { recursive: true, force: true });
    log.success(`Skill "${name}" removed.`);
  } catch (e) {
    log.error(`Failed to remove skill: ${skillDir}`);
    process.exit(1);
  }
}

export async function cmdAuthClear(name: string) {
  const skills = await loadAllSkills(SKILLS_DIR);
  const skill = skills.find(s => s.name === name);
  if (!skill) {
    log.error(`Skill "${name}" not found. Run "paipai skill list" to see available skills.`);
    process.exit(1);
  }

  const cookiePath = await getCookiePath(skill);
  const lsPath = await getLocalStoragePath(skill);
  let cleared = false;

  if (existsSync(cookiePath)) {
    try {
      await rm(cookiePath);
      log.success(`Cookie cleared for "${name}".`);
      cleared = true;
    } catch (e) {
      log.error(`Failed to remove cookie: ${cookiePath}`);
    }
  }

  if (existsSync(lsPath)) {
    try {
      await rm(lsPath);
      log.success(`localStorage cleared for "${name}".`);
      cleared = true;
    } catch (e) {
      log.error(`Failed to remove localStorage: ${lsPath}`);
    }
  }

  if (!cleared) {
    log.warn(`Skill "${name}" has no saved credentials.`);
  } else {
    log.info('Next run will re-authorize.');
  }
}
