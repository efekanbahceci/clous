import path from 'node:path';
import { resolveSchemaPath } from '../config/paths.js';
import { loadSchema } from '../utils/loader.js';
import { logger } from '../utils/logger.js';
import { ansi } from '../utils/ansi.js';

export interface ValidateOptions {
  cwd?: string;
  schema?: string;
}

export async function validateCommand(options: ValidateOptions = {}): Promise<void> {
  const cwd = options.cwd || process.cwd();
  const schemaPath = resolveSchemaPath(cwd, options.schema);

  logger.info(`Validating schema at: ${ansi.dim(path.relative(cwd, schemaPath) || schemaPath)}`);

  const appSchema = await loadSchema(schemaPath);

  logger.success(`Schema validation passed successfully (v${appSchema.version})`);
  logger.plain('');
  logger.plain('Schema summary:');

  for (const table of appSchema.tables) {
    const pk = table.columns.find((c) => c.isPrimaryKey)?.name || 'none';
    const fkCount = table.columns.filter((c) => c.references).length;
    const policyCount = table.policies.length;
    const indexCount = table.indexes.length;

    logger.plain(`  Table: ${ansi.bold(table.name)}`);
    logger.plain(`    Columns: ${table.columns.length} (Primary Key: "${pk}")`);
    logger.plain(`    Foreign Keys: ${fkCount}`);
    logger.plain(`    Indexes: ${indexCount}`);
    logger.plain(`    RLS Policies: ${policyCount}`);
  }
}
