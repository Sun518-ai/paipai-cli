// src/commands/skill.ts — paipai skill list / run / init / remove

import { join, relative } from 'node:path';
import { mkdir, writeFile, readdir, rm } from 'node:fs/promises';
import { loadAllSkills } from '../core/loader.ts';
import { runSkill, runStep } from '../core/runner.ts';
import { log } from '../utils/log.ts';
import type { Skill } from '../core/types.ts';

const SKILLS_DIR = join(process.cwd(), 'skills');

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

export async function cmdSkillRun(skillName: string, rawArgs: string[]) {
  const skills = await loadAllSkills(SKILLS_DIR);
  const skill = skills.find(s => s.name === skillName);
  if (!skill) {
    log.error(`Skill "${skillName}" not found. Run "paipai skill list" to see available skills.`);
    process.exit(1);
  }

  // 解析参数（支持 --key value 和 --key=value 两种格式）
  const args: Record<string, string | number | boolean> = {};
  const unknownFlags: string[] = [];

  for (let i = 0; i < rawArgs.length; i++) {
    const arg = rawArgs[i];
    if (!arg.startsWith('--')) {
      unknownFlags.push(arg);
      continue;
    }

    // --key=value 格式
    if (arg.includes('=')) {
      const [key, ...rest] = arg.slice(2).split('=');
      const val = rest.join('=');
      const matchedArg = skill.meta.args.find(a => a.name === key);
      if (matchedArg) {
        args[matchedArg.name] = matchedArg.type === 'number' ? Number(val) : val;
      } else {
        unknownFlags.push(`--${key}`);
      }
      continue;
    }

    // --key value 格式
    const matchedArg = skill.meta.args.find(a => a.name === arg.slice(2));
    if (matchedArg) {
      const next = rawArgs[i + 1];
      if (next && !next.startsWith('--')) {
        args[matchedArg.name] = matchedArg.type === 'number' ? Number(next) : next;
        i++; // skip next
      } else {
        args[matchedArg.name] = true;
      }
    } else {
      unknownFlags.push(arg);
    }
  }

  // 未知 flag 检测
  if (unknownFlags.length > 0) {
    log.warn(`Unknown argument(s): ${unknownFlags.join(', ')}`);
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

  const ctx = { skill, args, skillDir: skill.dir };

  if (skill.stepPaths.length > 0 && !skill.mainPath) {
    // 无 main.sh，按顺序执行各 step
    for (const step of skill.stepPaths) {
      const stepName = relative(skill.dir, step);
      log.info(`  → ${stepName}`);
      const code = await runStep(step, ctx);
      if (code !== 0) {
        log.error(`Step ${stepName} exited with code ${code}`);
        process.exit(code);
      }
    }
  } else {
    // 执行 main.sh
    const code = await runSkill(ctx);
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
