import fs from 'node:fs';
import path from 'node:path';
import { resolveSchemaPath } from '../config/paths.js';
import { generateCommand } from './generate.js';
import { logger } from '../utils/logger.js';
import { ansi } from '../utils/ansi.js';
import { ui } from '../utils/ui.js';

export interface DevOptions {
  cwd?: string;
  schema?: string;
  outDir?: string;
}

export async function devCommand(options: DevOptions = {}): Promise<void> {
  const cwd = options.cwd || process.cwd();
  const schemaPath = resolveSchemaPath(cwd, options.schema);
  const outDir = path.resolve(cwd, options.outDir || 'generated');

  await ui.animateBanner('0.1.0');

  ui.box({
    title: 'Clous Live Watcher',
    borderColor: ansi.cyan,
    minWidth: 64,
    lines: [
      `Target    ${ansi.bold(path.relative(cwd, schemaPath) || schemaPath)}`,
      `Output    ${ansi.dim(path.relative(cwd, outDir) || outDir)}`,
      `Status    ${ansi.green('Active')} (Automatic recompilation on save)`,
      '',
      ansi.dim('Press Ctrl+C to terminate session.'),
    ],
  });
  console.log('');

  // Initial compilation
  try {
    await generateCommand({ ...options, silent: false });
  } catch (err: any) {
    logger.error(`Initial compilation failed: ${err.message}`);
  }

  let debounceTimer: NodeJS.Timeout | null = null;

  const watcher = fs.watch(schemaPath, (eventType) => {
    if (eventType === 'change' || eventType === 'rename') {
      if (debounceTimer) {
        clearTimeout(debounceTimer);
      }

      debounceTimer = setTimeout(async () => {
        const time = new Date().toLocaleTimeString();
        console.log(`  ${ui.badge('WATCH')} ${ansi.dim(`[${time}]`)} Schema change detected. Recompiling...`);
        try {
          await generateCommand({ ...options, silent: false });
        } catch (err: any) {
          logger.error(`Compilation error: ${err.message}`);
        }
      }, 150);
    }
  });

  process.on('SIGINT', () => {
    watcher.close();
    console.log('');
    logger.info('Dev watcher stopped.');
    process.exit(0);
  });
}
