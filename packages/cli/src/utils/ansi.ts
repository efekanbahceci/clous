/**
 * ANSI color helpers for clean terminal output without external dependencies.
 */
const enabled =
  !process.env.NO_COLOR &&
  (process.stdout.isTTY || process.env.FORCE_COLOR === '1');

function format(open: number, close: number) {
  return (str: string | number) =>
    enabled ? `\x1b[${open}m${str}\x1b[${close}m` : String(str);
}

export const ansi = {
  bold: format(1, 22),
  dim: format(2, 22),
  italic: format(3, 23),
  underline: format(4, 24),
  red: format(31, 39),
  green: format(32, 39),
  yellow: format(33, 39),
  blue: format(34, 39),
  magenta: format(35, 39),
  cyan: format(36, 39),
  gray: format(90, 39),
};
