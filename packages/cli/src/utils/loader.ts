import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import type { SchemaNode } from '@clous/core';

/**
 * Loads and extracts the SchemaNode instance exported from a user's schema file.
 * Supports schema.ts, schema.js, with default export or named export (appSchema, schema).
 */
export async function loadSchema(schemaFilePath: string): Promise<SchemaNode> {
  const resolvedPath = path.resolve(schemaFilePath);
  if (!fs.existsSync(resolvedPath)) {
    throw new Error(`Schema file not found at: ${resolvedPath}`);
  }

  let mod: Record<string, any>;

  // Attempt 1: Direct native dynamic import (works for .js, .mjs, and Node.js with native TS support)
  try {
    const fileUrl = pathToFileURL(resolvedPath).href + `?t=${Date.now()}`;
    mod = await import(fileUrl);
  } catch (err: any) {
    // Attempt 2: If TypeScript execution failed (e.g. unknown file extension .ts),
    // transpile using TypeScript compiler API and load via temporary or data URL
    if (resolvedPath.endsWith('.ts')) {
      mod = await transpileAndImport(resolvedPath);
    } else {
      throw err;
    }
  }

  // Find SchemaNode in exports
  const schemaInstance = findSchemaNode(mod);
  if (!schemaInstance) {
    throw new Error(
      `No valid SchemaNode export found in ${schemaFilePath}. ` +
      `Ensure you export your schema: "export const appSchema = schema({ ... })" or "export default schema({ ... })".`
    );
  }

  return schemaInstance;
}

function findSchemaNode(mod: Record<string, any>): SchemaNode | null {
  if (isSchemaNode(mod.default)) {
    return mod.default;
  }
  if (isSchemaNode(mod.appSchema)) {
    return mod.appSchema;
  }
  if (isSchemaNode(mod.schema)) {
    return mod.schema;
  }

  // Iterate all named exports
  for (const value of Object.values(mod)) {
    if (isSchemaNode(value)) {
      return value;
    }
  }

  return null;
}

function isSchemaNode(val: any): val is SchemaNode {
  return (
    val !== null &&
    typeof val === 'object' &&
    typeof val.version === 'string' &&
    Array.isArray(val.tables)
  );
}

async function transpileAndImport(tsFilePath: string): Promise<Record<string, any>> {
  let ts: any;
  try {
    ts = (await import('typescript')).default;
  } catch {
    throw new Error(
      `Failed to load TypeScript compiler to transpile "${tsFilePath}". ` +
      `Please ensure typescript is installed or run using "tsx".`
    );
  }

  const sourceCode = fs.readFileSync(tsFilePath, 'utf8');
  const transpiled = ts.transpileModule(sourceCode, {
    compilerOptions: {
      module: ts.ModuleKind.ESNext,
      target: ts.ScriptTarget.ES2022,
    },
  });

  // Write temporary file in .clous cache or system temp
  const tmpDir = path.join(path.dirname(tsFilePath), '.clous', '.cache');
  if (!fs.existsSync(tmpDir)) {
    fs.mkdirSync(tmpDir, { recursive: true });
  }

  const tmpFile = path.join(tmpDir, `schema-${Date.now()}.mjs`);
  fs.writeFileSync(tmpFile, transpiled.outputText, 'utf8');

  try {
    const fileUrl = pathToFileURL(tmpFile).href;
    const mod = await import(fileUrl);
    return mod;
  } finally {
    try {
      fs.unlinkSync(tmpFile);
    } catch {
      // Ignore cleanup error
    }
  }
}
