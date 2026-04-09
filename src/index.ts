// src/index.ts — CLI 入口

import { log } from './utils/log.ts';
import { cmdSkillList, cmdSkillRun, cmdSkillInit, cmdSkillRemove } from './commands/skill.ts';
import { cmdDoctor } from './commands/doctor.ts';

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
