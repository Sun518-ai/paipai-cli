// src/core/runner.ts — 执行 Skill 的 main.sh 或 stepN 脚本

import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import type { RunContext } from './types.ts';

function buildEnv(args: Record<string, string | number | boolean>): Record<string, string> {
  return Object.fromEntries(
    Object.entries(args).map(([k, v]) => [`SKILL_ARG_${k.toUpperCase().replace(/-/g, '_')}`, String(v)])
  );
}

function runScript(scriptPath: string, ctx: RunContext): Promise<number> {
  return new Promise((resolve, reject) => {
    const { skill, args, skillDir } = ctx;
    const env = {
      ...process.env,
      SKILL_NAME: skill.name,
      SKILL_DIR: skillDir,
      PAIPAI_DEBUG: '1',
      ...buildEnv(args),
    };

    const child = spawn('bash', [scriptPath], {
      cwd: skillDir,
      env,
      stdio: 'inherit',
    });

    child.on('exit', code => resolve(code ?? 0));
    child.on('error', reject);
  });
}

export function runSkill(ctx: RunContext): Promise<number> {
  const { skill } = ctx;
  if (!skill.mainPath) {
    return Promise.reject(new Error(`Skill "${skill.name}" has no main.sh or main.ts`));
  }
  return runScript(skill.mainPath, ctx);
}

export async function runStep(stepPath: string, ctx: RunContext): Promise<number> {
  return runScript(stepPath, ctx);
}
