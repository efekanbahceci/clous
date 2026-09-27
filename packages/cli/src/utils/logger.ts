import { ansi } from './ansi.js';

export const logger = {
  info(msg: string): void {
    console.log(`${ansi.cyan('[clous]')} ${msg}`);
  },

  success(msg: string): void {
    console.log(`${ansi.green('[clous:success]')} ${msg}`);
  },

  warn(msg: string): void {
    console.warn(`${ansi.yellow('[clous:warn]')} ${msg}`);
  },

  error(msg: string | Error): void {
    const text = msg instanceof Error ? msg.message : msg;
    console.error(`${ansi.red('[clous:error]')} ${text}`);
  },

  plain(msg: string): void {
    console.log(msg);
  },

  table(rows: Array<[string, string]>): void {
    const maxKeyLen = Math.max(...rows.map(([k]) => k.length), 0);
    for (const [key, value] of rows) {
      console.log(`  ${ansi.dim(key.padEnd(maxKeyLen + 2))} ${value}`);
    }
  },
};
