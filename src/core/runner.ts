// src/core/runner.ts — 执行 Skill 的 main.sh 或 stepN 脚本

import { spawn } from 'node:child_process';
import { join } from 'node:path';
import type { RunContext } from './types.ts';

export function runSkill(ctx: RunContext): Promise<number> {
  return new Promise((resolve, reject) => {
    const { skill, args, skillDir } = ctx;
    if (!skill.mainPath) {
      reject(new Error(`Skill "${skill.name}" has no main.sh or main.ts`));
      return;
    }

    const env = {
      ...process.env,
      SKILL_NAME: skill.name,
      SKILL_DIR: skillDir,
      PAIPAI_DEBUG: '1',
      ...Object.fromEntries(
        Object.entries(args).map(([k, v]) => [`SKILL_ARG_${k.toUpperCase()}`, String(v)])
      ),
    };

    const child = spawn('bash', [skill.mainPath], {
      cwd: skillDir,
      env,
      stdio: 'inherit',
    });

    child.on('exit', code => resolve(code ?? 0));
    child.on('error', reject);
  });
}

export async function runStep(stepPath: string, ctx: RunContext): Promise<number> {
  return new Promise((resolve, reject) => {
    const { args, skillDir } = ctx;
    const env = {
      ...process.env,
      SKILL_NAME: ctx.skill.name,
      SKILL_DIR: skillDir,
      PAIPAI_DEBUG: '1',
      ...Object.fromEntries(
        Object.entries(args).map(([k, v]) => [`SKILL_ARG_${k.toUpperCase()}`, String(v)])
      ),
    };

    const child = spawn('bash', [stepPath], {
      cwd: skillDir,
      env,
      stdio: 'inherit',
    });

    child.on('exit', code => resolve(code ?? 0));
    child.on('error', reject);
  });
}
