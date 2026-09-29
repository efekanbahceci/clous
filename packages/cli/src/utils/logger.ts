import { ansi } from './ansi.js';
import { ui } from './ui.js';

export const logger = {
  info(msg: string): void {
    console.log(`  ${ui.badge('INFO')} ${msg}`);
  },

  success(msg: string): void {
    console.log(`  ${ui.badge('DONE')} ${msg}`);
  },

  warn(msg: string): void {
    console.warn(`  ${ui.badge('WARN')} ${msg}`);
  },

  error(msg: string | Error): void {
    const text = msg instanceof Error ? msg.message : msg;
    console.error(`  ${ui.badge('ERROR')} ${ansi.red(text)}`);
  },

  plain(msg: string = ''): void {
    console.log(msg);
  },

  table(rows: Array<[string, string]>): void {
    const maxKeyLen = Math.max(...rows.map(([k]) => ansi.visibleLength(k)), 0);
    for (const [key, value] of rows) {
      console.log(`    ${ansi.dim(key.padEnd(maxKeyLen + 2))} ${value}`);
    }
  },

  box: ui.box,
  card: ui.card,
  divider: ui.divider,
};
