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
    logger.info(`Loading schema from: ${ansi.dim(path.relative(cwd, schemaPath) || schemaPath)}`);
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
    logger.success(
      `Compiled ${appSchema.tables.length} tables in ${elapsed}ms`
    );
    logger.plain('');
    logger.plain('Generated files:');
    logger.plain(`  ${ansi.cyan('•')} ${path.relative(cwd, sqlPath)} (PostgreSQL DDL with RLS)`);
    logger.plain(`  ${ansi.cyan('•')} ${path.relative(cwd, dtsPath)} (TypeScript .d.ts types)`);
    logger.plain(`  ${ansi.cyan('•')} ${path.relative(cwd, openApiPath)} (OpenAPI 3.0 Spec)`);
  }

  return { sqlPath, dtsPath, openApiPath };
}
