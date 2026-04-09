// src/index.ts — CLI 入口

import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { log } from './utils/log.ts';
import { cmdSkillList, cmdSkillRun, cmdSkillInit, cmdSkillRemove } from './commands/skill.ts';
import { cmdDoctor } from './commands/doctor.ts';

// 加载 ~/.paipairc 配置文件，注入环境变量
function loadRc() {
  const rcPath = join(homedir(), '.paipairc');
  if (!existsSync(rcPath)) return;
  const lines = readFileSync(rcPath, 'utf-8').split('\n');
  for (const raw of lines) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    const val = line.slice(eq + 1).trim().replace(/^["']|["']$/g, '');
    if (key && val && !process.env[key]) {
      process.env[key] = val;
    }
  }
}

loadRc();

const [, , cmd, subcmd, ...rest] = process.argv;

function printHelp() {
  console.log(`
  🐲 paipai-cli — AI Skill CLI Framework

  Usage:
    paipai skill list                      列出所有技能
    paipai run <name> [--arg value...]    运行指定技能
    paipai skill:init <name>              创建新技能
    paipai skill:remove <name>            删除技能
    paipai doctor                          环境检查
    paipai help                            显示帮助

  Examples:
    paipai skill list
    paipai run example --target paipai
    paipai skill:init my-skill
    paipai doctor
`);
}

async function main() {
  if (!cmd || cmd === 'help' || cmd === '--help' || cmd === '-h') {
    printHelp();
    return;
  }

  switch (cmd) {
    case 'skill': {
      if (subcmd === 'list' || !subcmd) {
        await cmdSkillList();
      } else if (subcmd === 'init') {
        const name = rest[0];
        if (!name) {
          log.error('Usage: paipai skill:init <name>');
          process.exit(1);
        }
        await cmdSkillInit(name);
      } else if (subcmd === 'remove') {
        const name = rest[0];
        if (!name) {
          log.error('Usage: paipai skill:remove <name>');
          process.exit(1);
        }
        await cmdSkillRemove(name);
      } else {
        log.error(`Unknown subcommand: skill ${subcmd}`);
        printHelp();
        process.exit(1);
      }
      break;
    }

    case 'run': {
      const skillName = subcmd;
      if (!skillName) {
        log.error('Usage: paipai run <skill-name> [--arg value...]');
        process.exit(1);
      }
      await cmdSkillRun(skillName, rest);
      break;
    }

    case 'skill:init': {
      const name = subcmd;
      if (!name) {
        log.error('Usage: paipai skill:init <name>');
        process.exit(1);
      }
      await cmdSkillInit(name);
      break;
    }

    case 'doctor': {
      await cmdDoctor();
      break;
    }

    default:
      log.error(`Unknown command: ${cmd}`);
      log.info(`Run "paipai help" for usage.`);
      process.exit(1);
  }
}

main().catch(e => {
  log.error(e.message || String(e));
  process.exit(1);
});
