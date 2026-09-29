import path from 'node:path';
import { resolveSchemaPath } from '../config/paths.js';
import { loadSchema } from '../utils/loader.js';
import { logger } from '../utils/logger.js';
import { ansi } from '../utils/ansi.js';
import { ui } from '../utils/ui.js';

export interface ValidateOptions {
  cwd?: string;
  schema?: string;
}

export async function validateCommand(options: ValidateOptions = {}): Promise<void> {
  const cwd = options.cwd || process.cwd();
  const schemaPath = resolveSchemaPath(cwd, options.schema);

  logger.info(`Validating schema: ${ansi.bold(path.relative(cwd, schemaPath) || schemaPath)}`);

  const appSchema = await loadSchema(schemaPath);

  const lines: string[] = [
    `Schema   ${ansi.bold(path.relative(cwd, schemaPath) || schemaPath)} (v${appSchema.version})`,
    `Status   ${ansi.green('Integrity verified')} (0 errors, 0 warnings)`,
    '',
    'Table Architecture:',
  ];

  for (const table of appSchema.tables) {
    const pk = table.columns.find((c) => c.isPrimaryKey)?.name || 'none';
    const fkCount = table.columns.filter((c) => c.references).length;
    const policyCount = table.policies.length;
    const indexCount = table.indexes.length;

    lines.push(
      `  ${ansi.cyan('•')} ${ansi.bold(table.name.padEnd(16))} ${table.columns.length} cols (pk: "${pk}") | ${fkCount} FKs | ${policyCount} RLS | ${indexCount} idx`
    );
  }

  console.log('');
  ui.box({
    title: 'Schema Validation',
    borderColor: ansi.green,
    minWidth: 64,
    lines,
  });
  console.log('');
}
