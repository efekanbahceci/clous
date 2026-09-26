import type { FastifyPluginAsync } from 'fastify';
import { validateSchemaAst, type SchemaNode } from '@clous/core';
import type { QueryExecutor } from '../db/executor.interface.js';
import type { AdminConfig } from '../config.js';

const startTime = Date.now();

export const metaRoutes: FastifyPluginAsync<{
  getSchema: () => SchemaNode;
  setSchema: (schema: SchemaNode) => void;
  executor: QueryExecutor;
  adminConfig?: AdminConfig;
}> = async (fastify, opts) => {
  const { getSchema, setSchema, executor, adminConfig } = opts;

  // 1. Healthcheck probe (Liveness & Readiness)
  fastify.get('/api/_clous/health', async (_req, reply) => {
    const isDbConnected = executor.isConnected;
    const uptimeSeconds = Math.floor((Date.now() - startTime) / 1000);

    const health = {
      status: isDbConnected ? 'healthy' : 'degraded',
      service: 'clous-runtime',
      version: getSchema().version,
      uptimeSeconds,
      database: isDbConnected ? 'connected' : 'disconnected',
      tablesCount: getSchema().tables.length,
      timestamp: new Date().toISOString(),
    };

    return reply.status(isDbConnected ? 200 : 503).send(health);
  });

  // 2. Introspection endpoint for Web Panel (Reads Active Schema AST)
  fastify.get('/api/_clous/schema', async (_req, reply) => {
    return reply.send({
      data: getSchema(),
    });
  });

  // 3. Metadata summary for Web Panel Dashboard
  fastify.get('/api/_clous/meta', async (_req, reply) => {
    const currentSchema = getSchema();
    const tablesMeta = currentSchema.tables.map((t) => ({
      name: t.name,
      columnsCount: t.columns.length,
      primaryKey: t.columns.find((c) => c.isPrimaryKey)?.name ?? null,
      policiesCount: t.policies.length,
      indexesCount: t.indexes.length,
      columns: t.columns.map((c) => ({
        name: c.name,
        type: c.type,
        isNullable: c.isNullable,
        isPrimaryKey: c.isPrimaryKey,
        hasDefault: c.defaultValue !== undefined,
        references: c.references ?? null,
      })),
    }));

    return reply.send({
      version: currentSchema.version,
      tables: tablesMeta,
    });
  });

  // 4. Schema Validator (Web Panel checks schema validity before publishing)
  fastify.post('/api/_clous/schema/validate', async (req, reply) => {
    try {
      const validated = validateSchemaAst(req.body);
      return reply.send({
        valid: true,
        schema: validated,
      });
    } catch (err: any) {
      return reply.status(400).send({
        valid: false,
        error: err.message,
        issues: err.issues || [],
      });
    }
  });

  // 5. Admin Schema Update / Migration Hook (Control Plane pushes updated schema)
  fastify.post('/api/_clous/schema/update', async (req, reply) => {
    if (!adminConfig?.allowSchemaUpdates) {
      return reply.status(403).send({
        statusCode: 403,
        error: 'Forbidden',
        message: 'Dynamic schema updates are disabled on this instance',
      });
    }

    const adminSecret = adminConfig.secret;
    const providedSecret = req.headers['x-clous-admin-secret'];

    if (adminSecret && providedSecret !== adminSecret) {
      return reply.status(401).send({
        statusCode: 401,
        error: 'Unauthorized',
        message: 'Invalid or missing X-Clous-Admin-Secret',
      });
    }

    try {
      const validatedSchema = validateSchemaAst(req.body);
      setSchema(validatedSchema);

      return reply.send({
        success: true,
        message: 'Schema successfully updated',
        version: validatedSchema.version,
      });
    } catch (err: any) {
      return reply.status(400).send({
        success: false,
        error: err.message,
      });
    }
  });
};
