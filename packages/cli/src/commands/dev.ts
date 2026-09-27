import fs from 'node:fs';
import path from 'node:path';
import { resolveSchemaPath } from '../config/paths.js';
import { generateCommand } from './generate.js';
import { logger } from '../utils/logger.js';
import { ansi } from '../utils/ansi.js';

export interface DevOptions {
  cwd?: string;
  schema?: string;
  outDir?: string;
}

export async function devCommand(options: DevOptions = {}): Promise<void> {
  const cwd = options.cwd || process.cwd();
  const schemaPath = resolveSchemaPath(cwd, options.schema);

  logger.info(`Starting Clous dev watcher on: ${ansi.cyan(path.relative(cwd, schemaPath) || schemaPath)}`);
  logger.plain(ansi.dim('Press Ctrl+C to stop watching.'));
  logger.plain('');

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
        logger.info(`[${time}] Change detected in schema. Recompiling...`);
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
    logger.plain('');
    logger.info('Dev watcher stopped.');
    process.exit(0);
  });
}
