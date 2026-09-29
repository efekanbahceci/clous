import fs from 'node:fs';
import path from 'node:path';
import {
  PostgresSqlEmitter,
  DtsEmitter,
  OpenApiEmitter,
} from '@clous/core';
import { resolveSchemaPath } from '../config/paths.js';
import { loadSchema } from '../utils/loader.js';
import { logger } from '../utils/logger.js';
import { ansi } from '../utils/ansi.js';
import { ui } from '../utils/ui.js';

export interface GenerateOptions {
  cwd?: string;
  schema?: string;
  outDir?: string;
  silent?: boolean;
}

export async function generateCommand(options: GenerateOptions = {}): Promise<{
  sqlPath: string;
  dtsPath: string;
  openApiPath: string;
}> {
  const cwd = options.cwd || process.cwd();
  const schemaPath = resolveSchemaPath(cwd, options.schema);
  const outDir = path.resolve(cwd, options.outDir || 'generated');

  if (!options.silent) {
    logger.info(`Compiling schema: ${ansi.bold(path.relative(cwd, schemaPath) || schemaPath)}`);
  }

  const startTime = Date.now();
  const appSchema = await loadSchema(schemaPath);

  // Ensure output directory exists
  if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
  }

  // 1. Emit PostgreSQL DDL
  const sqlEmitter = new PostgresSqlEmitter();
  const sqlContent = sqlEmitter.emit(appSchema, {
    includeExtensions: true,
    includeAuthHelpers: true,
    enableRlsByDefault: true,
  });
  const sqlPath = path.join(outDir, 'schema.sql');
  fs.writeFileSync(sqlPath, sqlContent, 'utf8');

  // 2. Emit TypeScript .d.ts types
  const dtsEmitter = new DtsEmitter();
  const dtsPath = path.join(outDir, 'db-types.d.ts');
  await dtsEmitter.writeToFile(dtsPath, appSchema);

  // 3. Emit OpenAPI 3.0 specification
  const openApiEmitter = new OpenApiEmitter();
  const openApiSpec = openApiEmitter.emit(appSchema, {
    title: 'Clous Generated API',
    description: 'Auto-generated REST API specification from Clous schema',
  });
  const openApiPath = path.join(outDir, 'openapi.json');
  fs.writeFileSync(openApiPath, JSON.stringify(openApiSpec, null, 2), 'utf8');

  const elapsed = Date.now() - startTime;

  if (!options.silent) {
    const relSql = path.relative(cwd, sqlPath);
    const relDts = path.relative(cwd, dtsPath);
    const relOpenApi = path.relative(cwd, openApiPath);

    console.log('');
    ui.box({
      title: `Generated Artifacts (${elapsed}ms)`,
      borderColor: ansi.green,
      minWidth: 64,
      lines: [
        `Schema:   ${ansi.bold(path.relative(cwd, schemaPath) || schemaPath)} (v${appSchema.version}, ${appSchema.tables.length} tables)`,
        `Target:   ${ansi.dim(path.relative(cwd, outDir) || outDir)}`,
        '',
        'Artifacts Created:',
        `  ${ansi.cyan('•')} ${ansi.bold(relSql.padEnd(26))} ${ansi.dim('PostgreSQL DDL (RLS + Functions)')}`,
        `  ${ansi.cyan('•')} ${ansi.bold(relDts.padEnd(26))} ${ansi.dim('TypeScript SDK Interfaces (.d.ts)')}`,
        `  ${ansi.cyan('•')} ${ansi.bold(relOpenApi.padEnd(26))} ${ansi.dim('OpenAPI 3.0 REST Specification')}`,
      ],
    });
    console.log('');
  }

  return { sqlPath, dtsPath, openApiPath };
}
