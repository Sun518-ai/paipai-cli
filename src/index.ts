#!/usr/bin/env bun
// src/index.ts — CLI 入口

import { log } from './utils/log.ts';
import { cmdSkillList, cmdSkillRun, cmdSkillInit, cmdSkillRemove, cmdAuthClear } from './commands/skill.ts';
import { cmdEnvList, cmdEnvSet, cmdEnvUnset } from './commands/env.ts';
import { cmdDoctor } from './commands/doctor.ts';
import { loadRcToEnv } from './core/rc.ts';

loadRcToEnv();

const [, , cmd, subcmd, ...rest] = process.argv;

function printHelp() {
  console.log(`
  🐲 paipai-cli — AI Skill CLI Framework

  Usage:
    paipai skill list                      列出所有技能
    paipai run <name> [--arg value...]    运行指定技能
    paipai skill:init <name>              创建新技能
    paipai skill:remove <name>            删除技能
    paipai auth clear <name>              清除技能授权
    paipai env list                        列出全局环境变量
    paipai env set <KEY> [VALUE]          设置环境变量
    paipai env unset <KEY>                删除环境变量
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

    case 'env': {
      if (subcmd === 'list' || !subcmd) {
        await cmdEnvList();
      } else if (subcmd === 'set') {
        const key = rest[0];
        if (!key) {
          log.error('Usage: paipai env set <KEY> [VALUE]');
          process.exit(1);
        }
        await cmdEnvSet(key, rest[1]);
      } else if (subcmd === 'unset') {
        const key = rest[0];
        if (!key) {
          log.error('Usage: paipai env unset <KEY>');
          process.exit(1);
        }
        cmdEnvUnset(key);
      } else {
        log.error(`Unknown subcommand: env ${subcmd}`);
        printHelp();
        process.exit(1);
      }
      break;
    }

    case 'doctor': {
      await cmdDoctor();
      break;
    }

    case 'auth': {
      if (subcmd === 'clear') {
        const name = rest[0];
        if (!name) {
          log.error('Usage: paipai auth clear <skill-name>');
          process.exit(1);
        }
        await cmdAuthClear(name);
      } else {
        log.error(`Unknown subcommand: auth ${subcmd || ''}`);
        printHelp();
        process.exit(1);
      }
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
