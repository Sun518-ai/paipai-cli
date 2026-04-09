// src/utils/log.ts — 彩色日志

const RESET = '\x1b[0m';
const BOLD = '\x1b[1m';
const DIM = '\x1b[2m';

const colors = {
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  white: '\x1b[37m',
};

type Color = keyof typeof colors;

function color(c: Color, msg: string) {
  return `${colors[c]}${msg}${RESET}`;
}

export const log = {
  info(msg: string) { console.log(`${color('blue', 'ℹ')} ${msg}`); },
  success(msg: string) { console.log(`${color('green', '✓')} ${msg}`); },
  warn(msg: string) { console.log(`${color('yellow', '⚠')} ${msg}`); },
  error(msg: string) { console.error(`${color('red', '✗')} ${msg}`); },
  debug(msg: string) { if (process.env.PAIPAI_DEBUG) console.log(`${color('dim', '···')} ${DIM}${msg}${RESET}`); },
  bold(msg: string) { console.log(`${BOLD}${msg}${RESET}`); },
  cyan(msg: string) { console.log(color('cyan', msg)); },
  skill(msg: string) { console.log(`${color('magenta', '◆')} ${color('white', msg)}`); },
};
