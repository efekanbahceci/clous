import { ansi } from './ansi.js';

export interface BoxOptions {
  title?: string;
  lines: string[];
  borderColor?: (str: string | number) => string;
  minWidth?: number;
  padding?: number;
}

export interface AnimateBannerOptions {
  frames?: number;
  intervalMs?: number;
}

export interface SlowMotionOptions {
  intervalMs?: number;
  statusMessage?: string;
}

export interface SlowMotionController {
  stop(): void;
  updateStatus(message: string): void;
}

const YAW_FRAMES: string[][] = [
  // 0: Face-on Frontal
  ['  ___ _', ' / __| |___ _  _ ___', '| (__| / _ \\ || (_-<', ' \\___|_\\___/\\_,_/__/'],
  // 1: 30 deg
  ['   __ _', '  / _| |__ _ _ __', ' | (_| / _\\ || (_-', '  \\__|_|__/\\_,_/__'],
  // 2: 60 deg
  ['    _ _', '   / | |_ _ _', '  | (| / \\| |(-', '   \\_|_|_/\\_,/_'],
  // 3: 90 deg (edge-on)
  ['       |', '       |', '       |', '       |'],
  // 4: 120 deg
  ['          _ _', '    _ _ _| | \\', '  -)| |/ \\ |) |', '  _\\,_/\\_|_|_/'],
  // 5: 150 deg
  ['            _ __', '  __ _ _ _| |_\\ \\', ' -)| || /_ \\ |) |', ' __/_\\,_/|__|_/'],
  // 6: 180 deg (reverse)
  ['             _ ___', ' ___ _  ___| |__\\ \\', '>-)| || / _ \\ |) |', ' /__/_\\,_/\\___|_/'],
  // 7: 210 deg
  ['            _ __', '  __ _ _ _| |_\\ \\', ' -)| || /_ \\ |) |', ' __/_\\,_/|__|_/'],
  // 8: 240 deg
  ['          _ _', '    _ _ _| | \\', '  -)| |/ \\ |) |', '  _\\,_/\\_|_|_/'],
  // 9: 270 deg (edge-on)
  ['       |', '       |', '       |', '       |'],
  // 10: 300 deg
  ['    _ _', '   / | |_ _ _', '  | (| / \\| |(-', '   \\_|_|_/\\_,/_'],
  // 11: 330 deg
  ['   __ _', '  / _| |__ _ _ __', ' | (_| / _\\ || (_-', '  \\__|_|__/\\_,_/__'],
  // 12: 360 deg (Face-on Frontal)
  ['  ___ _', ' / __| |___ _  _ ___', '| (__| / _ \\ || (_-<', ' \\___|_\\___/\\_,_/__/'],
];

const SPECTRUM_256 = [
  '\x1b[38;5;51m',  // Electric Cyan
  '\x1b[38;5;45m',  // Cyan Blue
  '\x1b[38;5;39m',  // Sky Blue
  '\x1b[38;5;75m',  // Soft Indigo
  '\x1b[38;5;141m', // Lavender
  '\x1b[38;5;177m', // Soft Purple
  '\x1b[38;5;213m', // Magenta / Pink
  '\x1b[38;5;207m', // Bright Orchid
  '\x1b[38;5;214m', // Warm Amber
  '\x1b[38;5;220m', // Gold
  '\x1b[38;5;48m',  // Mint
  '\x1b[38;5;42m',  // Spring Emerald
  '\x1b[38;5;36m',  // Deep Teal
];

const SPECTRUM_16 = [
  '\x1b[96m', // Bright Cyan
  '\x1b[36m', // Cyan
  '\x1b[94m', // Bright Blue
  '\x1b[34m', // Blue
  '\x1b[95m', // Bright Magenta
  '\x1b[35m', // Magenta
  '\x1b[93m', // Bright Yellow
  '\x1b[33m', // Yellow
  '\x1b[92m', // Bright Green
  '\x1b[32m', // Green
];

function getPalette(): string[] {
  if (typeof process.stdout.getColorDepth === 'function' && process.stdout.getColorDepth() >= 8) {
    return SPECTRUM_256;
  }
  return SPECTRUM_16;
}

function renderRotatedLogoLines(
  yawIdx: number,
  colorOffset: number,
  isFinal: boolean,
  version: string
): string[] {
  const ver = ansi.dim(`v${version}`);
  const tag = ansi.dim('Next-Gen BaaS & Type-Safe ORM Platform');
  const palette = getPalette();
  const safeYawIdx = ((yawIdx % YAW_FRAMES.length) + YAW_FRAMES.length) % YAW_FRAMES.length;
  const lines = YAW_FRAMES[safeYawIdx];

  return lines.map((line, lineIdx) => {
    let colored = '';
    for (let c = 0; c < line.length; c++) {
      const ch = line[c];
      if (ch === ' ') {
        colored += ' ';
      } else if (isFinal) {
        colored += ansi.cyan(ch);
      } else {
        const color = palette[(c + lineIdx * 2 + colorOffset * 2) % palette.length];
        colored += `${color}${ch}\x1b[0m`;
      }
    }

    const pad = ' '.repeat(Math.max(0, 24 - line.length));
    let side = '';
    if (lineIdx === 2) {
      side = `    ${ansi.bold('Clous')} ${ver}`;
    } else if (lineIdx === 3) {
      side = `    ${tag}`;
    }

    return colored + pad + side;
  });
}

export const ui = {
  /**
   * Static ASCII logo and header for Clous.
   */
  banner(version: string = '0.1.0'): void {
    const lines = renderRotatedLogoLines(0, 0, true, version);
    console.log('');
    for (const line of lines) {
      console.log(line);
    }
    console.log('');
  },

  /**
   * Smoothly animates the Clous ASCII logo with a full 3D rotation flip and shifting spectrum wave.
   * Restores terminal state and gracefully falls back in non-TTY/CI environments.
   */
  async animateBanner(
    version: string = '0.1.0',
    options: AnimateBannerOptions = {}
  ): Promise<void> {
    const isTTY = Boolean(
      process.stdout.isTTY &&
      !process.env.CI &&
      !process.env.NO_COLOR &&
      process.env.TERM !== 'dumb'
    );

    if (!isTTY) {
      ui.banner(version);
      return;
    }

    const intervalMs = options.intervalMs ?? 35;
    const totalFrames = YAW_FRAMES.length;

    // Temporarily hide cursor for smooth frame transitions
    process.stdout.write('\x1b[?25l');

    const cleanup = () => {
      process.stdout.write('\x1b[?25h');
    };

    process.once('SIGINT', cleanup);

    try {
      process.stdout.write('\n');
      for (let i = 0; i < totalFrames; i++) {
        const isFinal = i === totalFrames - 1;
        const lines = renderRotatedLogoLines(i, i, isFinal, version);

        if (i > 0) {
          // Move cursor up 5 lines (4 logo lines + 1 trailing line) and to col 0
          process.stdout.write('\x1b[5A\r');
        }

        for (const line of lines) {
          process.stdout.write(`\x1b[2K${line}\n`);
        }
        process.stdout.write('\x1b[2K\n');

        if (!isFinal) {
          await new Promise((resolve) => setTimeout(resolve, intervalMs));
        }
      }
    } finally {
      process.removeListener('SIGINT', cleanup);
      process.stdout.write('\x1b[?25h');
    }
  },

  /**
   * Starts a slow-motion rotating and color-shifting logo animation during waiting operations.
   * Plays the initial fast 3D spin, then transitions into a slow-motion loop until stopped.
   */
  async startSlowMotionBanner(
    version: string = '0.1.0',
    options: SlowMotionOptions = {}
  ): Promise<SlowMotionController> {
    const isTTY = Boolean(
      process.stdout.isTTY &&
      !process.env.CI &&
      !process.env.NO_COLOR &&
      process.env.TERM !== 'dumb'
    );

    if (!isTTY) {
      ui.banner(version);
      if (options.statusMessage) {
        console.log(`  ${options.statusMessage}\n`);
      }
      return {
        stop() {},
        updateStatus() {},
      };
    }

    // Step 1: Run fast 3D spin intro
    await ui.animateBanner(version, { intervalMs: 32 });

    // Step 2: Begin slow-motion loop
    const slowInterval = options.intervalMs ?? 220;
    let step = 0;
    let currentStatus = options.statusMessage || '';
    let stopped = false;

    // Hide cursor
    process.stdout.write('\x1b[?25l');

    const cleanup = () => {
      if (!stopped) {
        stopped = true;
        clearInterval(timer);
        process.stdout.write('\x1b[?25h');
      }
    };

    process.once('SIGINT', cleanup);

    // Initial render of status line below the logo
    if (currentStatus) {
      process.stdout.write(`  ${currentStatus}\n`);
    }

    const timer = setInterval(() => {
      if (stopped) return;
      step++;
      // Rotate 3D slowly (advance 1 yaw frame every 2 ticks = ~440ms)
      const yawIdx = Math.floor(step / 2) % YAW_FRAMES.length;
      const colorOffset = step;
      const lines = renderRotatedLogoLines(yawIdx, colorOffset, false, version);

      // Move cursor up: 4 logo lines + 1 trailing line + 1 status line (if present)
      const linesUp = currentStatus ? 6 : 5;
      process.stdout.write(`\x1b[${linesUp}A\r`);

      for (const line of lines) {
        process.stdout.write(`\x1b[2K${line}\n`);
      }
      process.stdout.write('\x1b[2K\n');

      if (currentStatus) {
        process.stdout.write(`\x1b[2K  ${currentStatus}\n`);
      }
    }, slowInterval);

    return {
      updateStatus(newMsg: string) {
        currentStatus = newMsg;
      },
      stop() {
        if (stopped) return;
        stopped = true;
        clearInterval(timer);
        process.removeListener('SIGINT', cleanup);

        // Render final static cyan logo at 0 deg, clear status line
        const finalLines = renderRotatedLogoLines(0, 0, true, version);
        const linesUp = currentStatus ? 6 : 5;
        process.stdout.write(`\x1b[${linesUp}A\r`);

        for (const line of finalLines) {
          process.stdout.write(`\x1b[2K${line}\n`);
        }
        process.stdout.write('\x1b[2K\n');
        if (currentStatus) {
          process.stdout.write('\x1b[2K'); // Clear status line
        }

        process.stdout.write('\x1b[?25h'); // Restore cursor
      },
    };
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
