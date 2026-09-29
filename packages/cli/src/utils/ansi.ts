/**
 * ANSI color and text formatting helpers for clean terminal output.
 * Zero external dependencies.
 */
const enabled =
  !process.env.NO_COLOR &&
  (process.stdout.isTTY || process.env.FORCE_COLOR === '1');

function format(open: number, close: number) {
  return (str: string | number) =>
    enabled ? `\x1b[${open}m${str}\x1b[${close}m` : String(str);
}

export const ansi = {
  // Styles
  bold: format(1, 22),
  dim: format(2, 22),
  italic: format(3, 23),
  underline: format(4, 24),
  inverse: format(7, 27),

  // Foreground Colors
  black: format(30, 39),
  red: format(31, 39),
  green: format(32, 39),
  yellow: format(33, 39),
  blue: format(34, 39),
  magenta: format(35, 39),
  cyan: format(36, 39),
  white: format(37, 39),
  gray: format(90, 39),

  // Background Colors
  bgBlack: format(40, 49),
  bgRed: format(41, 49),
  bgGreen: format(42, 49),
  bgYellow: format(43, 49),
  bgBlue: format(44, 49),
  bgMagenta: format(45, 49),
  bgCyan: format(46, 49),
  bgWhite: format(47, 49),

  /**
   * Strips ANSI escape codes to compute visible character length.
   */
  strip(str: string): string {
    return str.replace(/\x1b\[[0-9;]*m/g, '');
  },

  /**
   * Returns visual character width of a string.
   */
  visibleLength(str: string): number {
    return ansi.strip(str).length;
  },
};
