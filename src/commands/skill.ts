// src/commands/skill.ts — paipai skill list / run / init

import { join, relative } from 'node:path';
import { mkdir, writeFile, readdir } from 'node:fs/promises';
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
    const trigger = s.meta.triggers[0] || `paipai run ${s.name}`;
    log.skill(`  ${s.name.padEnd(20)} ${s.meta.description || '(no description)'}`);
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

  // 解析参数
  const args: Record<string, string | number | boolean> = {};
  for (const argDef of skill.meta.args) {
    const idx = rawArgs.indexOf(`--${argDef.name}`);
    if (idx !== -1 && rawArgs[idx + 1]) {
      const val = rawArgs[idx + 1];
      args[argDef.name] = argDef.type === 'number' ? Number(val) : val;
    }
    if (rawArgs.includes(`--${argDef.name}`) && !args[argDef.name]) {
      args[argDef.name] = true;
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
