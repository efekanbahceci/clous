import { ansi } from './ansi.js';

export interface BoxOptions {
  title?: string;
  lines: string[];
  borderColor?: (str: string | number) => string;
  minWidth?: number;
  padding?: number;
}

export const ui = {
  /**
   * Minimalist ASCII logo and header for Clous.
   */
  banner(version: string = '0.1.0'): void {
    const brand = ansi.bold(ansi.cyan('  clous'));
    const tag = ansi.dim('Next-Gen BaaS & Type-Safe ORM Platform');
    const ver = ansi.dim(`v${version}`);

    console.log('');
    console.log(`  ${ansi.cyan('___ _')}`);
    console.log(` ${ansi.cyan('/ __| |___ _  _ ___')}`);
    console.log(`${ansi.cyan('| (__| / _ \\ || (_-<')}    ${ansi.bold('Clous')} ${ver}`);
    console.log(` ${ansi.cyan('\\___|_\\___/\\_,_/__/')}    ${tag}`);
    console.log('');
  },

  /**
   * Status badges with subtle background or high-contrast styling.
   */
  badge(
    type: 'DONE' | 'READY' | 'WATCH' | 'AUTH' | 'INFO' | 'WARN' | 'ERROR' | 'LINK' | string,
    message?: string
  ): string {
    let tag = '';
    switch (type) {
      case 'DONE':
      case 'READY':
        tag = ansi.bold(ansi.green(`[${type}]`));
        break;
      case 'WATCH':
        tag = ansi.bold(ansi.cyan(`[${type}]`));
        break;
      case 'AUTH':
      case 'LINK':
        tag = ansi.bold(ansi.magenta(`[${type}]`));
        break;
      case 'WARN':
        tag = ansi.bold(ansi.yellow(`[${type}]`));
        break;
      case 'ERROR':
        tag = ansi.bold(ansi.red(`[${type}]`));
        break;
      default:
        tag = ansi.bold(ansi.blue(`[${type}]`));
        break;
    }

    return message ? `${tag} ${message}` : tag;
  },

  /**
   * Renders a clean card with rounded borders.
   */
  box(options: BoxOptions): void {
    const {
      title,
      lines,
      borderColor = ansi.dim,
      minWidth = 60,
      padding = 2,
    } = options;

    const padStr = ' '.repeat(padding);

    // Compute maximum content width
    let contentWidth = minWidth;
    if (title) {
      contentWidth = Math.max(contentWidth, ansi.visibleLength(title) + 6);
    }
    for (const line of lines) {
      contentWidth = Math.max(contentWidth, ansi.visibleLength(line) + padding * 2);
    }

    // Top border
    let topBorder = '';
    if (title) {
      const titleDecorated = `─ ${ansi.bold(title)} `;
      const titleLen = ansi.visibleLength(titleDecorated);
      const remainingDashes = Math.max(0, contentWidth - titleLen);
      topBorder = borderColor(`╭─${titleDecorated}${'─'.repeat(remainingDashes)}╮`);
    } else {
      topBorder = borderColor(`╭${'─'.repeat(contentWidth)}╮`);
    }

    console.log(topBorder);

    // Body lines
    for (const line of lines) {
      const lineLen = ansi.visibleLength(line);
      const trailingSpaces = Math.max(0, contentWidth - lineLen - padding);
      const leftBorder = borderColor('│');
      const rightBorder = borderColor('│');
      console.log(`${leftBorder}${padStr}${line}${' '.repeat(trailingSpaces)}${rightBorder}`);
    }

    // Bottom border
    const bottomBorder = borderColor(`╰${'─'.repeat(contentWidth)}╯`);
    console.log(bottomBorder);
  },

  /**
   * Formats a clean key-value card with aligned columns inside a rounded box.
   */
  card(
    title: string,
    rows: Array<[string, string]>,
    options: { borderColor?: (s: string | number) => string; minWidth?: number } = {}
  ): void {
    const maxKeyLen = Math.max(...rows.map(([k]) => ansi.visibleLength(k)), 0);
    const lines = rows.map(([key, value]) => {
      const padKey = ansi.dim(key.padEnd(maxKeyLen + 2));
      return `${padKey}  ${value}`;
    });

    ui.box({
      title,
      lines,
      borderColor: options.borderColor || ansi.dim,
      minWidth: options.minWidth || 56,
      padding: 2,
    });
  },

  /**
   * Clean section divider line.
   */
  divider(label?: string, width: number = 60): void {
    if (!label) {
      console.log(ansi.dim('─'.repeat(width)));
      return;
    }
    const labelFormatted = `─ ${ansi.bold(label)} `;
    const labelLen = ansi.visibleLength(labelFormatted);
    const remaining = Math.max(0, width - labelLen);
    console.log(ansi.dim(`${labelFormatted}${'─'.repeat(remaining)}`));
  },
};
