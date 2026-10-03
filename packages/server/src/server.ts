import Fastify, { type FastifyInstance } from 'fastify';
import type { SchemaNode } from '@clous/core';
import type { ClousServerOptions } from './config.js';
import type { QueryExecutor } from './db/executor.interface.js';
import { PgExecutor } from './db/pg-executor.js';
import { MemoryExecutor } from './db/memory-executor.js';
import { securityPlugin } from './plugins/security.js';
import { authPlugin } from './plugins/auth.js';
import { setupErrorHandler } from './plugins/error-handler.js';
import { crudRoutes } from './routes/crud.js';
import { metaRoutes } from './routes/meta.js';
import { openapiRoutes } from './routes/openapi.js';
import { telemetryPlugin } from './plugins/telemetry.js';
import { telemetryRoutes } from './routes/telemetry.js';


export async function createClousServer(
  options: ClousServerOptions
): Promise<FastifyInstance> {
  const app = Fastify({
    logger: options.server?.logger ?? false,
  });

  // 1. Setup Query Executor (PostgreSQL or In-Memory fallback)
  let executor: QueryExecutor;
  if (
    options.database?.pool ||
    options.database?.connectionString ||
    options.database?.provider === 'postgres'
  ) {
    executor = new PgExecutor(
      options.database.pool || {
        connectionString: options.database.connectionString,
        max: options.database.maxConnections ?? 20,
      }
    );
  } else {
    executor = new MemoryExecutor();
  }

  // 2. Setup Centralized Error Handler
  setupErrorHandler(app);

  // 2.5 Register Telemetry Plugin (Metrics & SSE)
  await app.register(telemetryPlugin);

  // 2.55 Register Cloud Sync (pushes traffic + schema to the Clous platform).
  // Must be registered before the DB inspector so it receives the startup schema event.
  const { cloudSyncPlugin } = await import('./plugins/cloud-sync.js');
  await app.register(cloudSyncPlugin);
  
  // 2.6 Register Env Scanner (for Real-time local .env watching)
  const { envScannerPlugin } = await import('./plugins/env-scanner.js');
  await app.register(envScannerPlugin);

  // 2.7 Register DB Inspector (for Real-time DB Schema Introspection)
  const { dbInspectorPlugin } = await import('./plugins/db-inspector.js');
  await app.register(dbInspectorPlugin);

  // 3. Register Security Plugin (CORS, Helmet, Rate Limiting)
  await app.register(securityPlugin, { config: options.security });

  // 4. Register Auth Plugin (JWT token verification & RLS claims)
  await app.register(authPlugin, { config: options.auth });

  // 5. Active Schema state management
  let currentSchema: SchemaNode = options.schema;
  const getSchema = () => currentSchema;
  const setSchema = (s: SchemaNode) => {
    currentSchema = s;
  };

  // 6. Register Web Panel Meta & Introspection Routes
  await app.register(metaRoutes, {
    getSchema,
    setSchema,
    executor,
    adminConfig: options.admin,
  });

  // 7. Register OpenAPI Spec & Scalar UI Docs
  await app.register(openapiRoutes, {
    getSchema,
  });

  // 7.5 Register Telemetry SSE Stream
  await app.register(telemetryRoutes, {
    adminConfig: options.admin,
  });

  // 8. Register Dynamic CRUD Routes for all tables
  await app.register(crudRoutes, {
    tables: currentSchema.tables,
    executor,
  });

  // 9. Graceful shutdown hook
  app.addHook('onClose', async () => {
    await executor.close();
  });

  return app;
}
