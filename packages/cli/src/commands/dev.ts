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
  const schemaExists = fs.existsSync(schemaPath);

  await ui.animateBanner('0.1.0');

  ui.box({
    title: 'Clous Live Watcher',
    borderColor: ansi.cyan,
    minWidth: 64,
    lines: [
      `Target    ${ansi.bold(path.relative(cwd, schemaPath) || schemaPath)}`,
      `Output    ${ansi.dim(path.relative(cwd, outDir) || outDir)}`,
      schemaExists
        ? `Status    ${ansi.green('Active')} (Automatic recompilation on save)`
        : `Status    ${ansi.yellow('Waiting')} (Schema file not found yet)`,
      '',
      ansi.dim('Press Ctrl+C to terminate session.'),
    ],
  });
  console.log('');

  let debounceTimer: NodeJS.Timeout | null = null;

  const compile = async (reason?: string) => {
    if (!fs.existsSync(schemaPath)) return;
    if (reason) {
      const time = new Date().toLocaleTimeString();
      console.log(`  ${ui.badge('WATCH')} ${ansi.dim(`[${time}]`)} ${reason}`);
    }
    try {
      await generateCommand({ ...options, silent: false });
    } catch (err: any) {
      logger.error(`Compilation error: ${err.message}`);
    }
  };

  const scheduleCompile = (reason: string) => {
    if (debounceTimer) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => void compile(reason), 150);
  };

  if (schemaExists) {
    await compile();
  } else {
    logger.warn(
      `No schema file found at ${path.relative(cwd, schemaPath) || schemaPath}. ` +
        `Run "clous init" to create one — the watcher will pick it up automatically.`
    );
  }

  // Watch the schema's directory instead of the file itself:
  // - fs.watch(file) throws ENOENT if the file doesn't exist yet,
  // - editors that save via rename would otherwise detach a file-level watcher.
  const schemaDir = path.dirname(schemaPath);
  const schemaFile = path.basename(schemaPath);

  let watcher: fs.FSWatcher;
  try {
    watcher = fs.watch(schemaDir, (_eventType, filename) => {
      if (filename && filename.toString() !== schemaFile) return;
      scheduleCompile('Schema change detected. Recompiling...');
    });
  } catch (err: any) {
    logger.error(`Unable to watch ${schemaDir}: ${err.message}`);
    process.exitCode = 1;
    return;
  }

  process.on('SIGINT', () => {
    watcher.close();
    console.log('');
    logger.info('Dev watcher stopped.');
    process.exit(0);
  });
}
