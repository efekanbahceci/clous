import type { FastifyPluginAsync, FastifyRequest, FastifyReply } from 'fastify';
import { telemetryEmitter, type TelemetryMetric } from '../plugins/telemetry.js';
import type { AdminConfig } from '../config.js';
import fs from 'node:fs';
import path from 'node:path';

interface TelemetryRouteOptions {
  adminConfig?: AdminConfig;
}

// Reads the linked project ID from .clous/project.json by walking up the directory tree.
function getLinkedProjectId(): string | null {
  let current = process.cwd();
  while (true) {
    const p = path.join(current, '.clous');
    if (fs.existsSync(p) && fs.statSync(p).isDirectory()) {
      try {
        const data = JSON.parse(fs.readFileSync(path.join(p, 'project.json'), 'utf8'));
        return data.projectId || null;
      } catch { return null; }
    }
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }
  return null;
}

export const telemetryRoutes: FastifyPluginAsync<TelemetryRouteOptions> = async (fastify, options) => {
  // Use a non-async handler + done callback to prevent Fastify from trying to send
  // a response after reply.hijack() — which would cause ERR_HTTP_HEADERS_SENT.
  fastify.get('/api/_clous/telemetry/stream', { 
    handler: (request: FastifyRequest, reply: FastifyReply) => {
      // 1. Auth check
      const adminSecret = options.adminConfig?.secret;
      if (adminSecret) {
        const authHeader = request.headers['authorization'] ?? '';
        const querySecret = (request.query as any)?.secret;
        const headerOk = authHeader.startsWith('Bearer ') && authHeader.split(' ')[1] === adminSecret;
        const queryOk  = querySecret === adminSecret;
        if (!headerOk && !queryOk) {
          reply.raw.writeHead(401, { 'Content-Type': 'application/json' });
          reply.raw.end(JSON.stringify({ error: 'Unauthorized: Invalid Admin Secret' }));
          return;
        }
      }

      // 2. Hijack the raw socket — Fastify will no longer touch this response.
      reply.hijack();

      // 3. Write SSE headers
      reply.raw.writeHead(200, {
        'Content-Type':  'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection':    'keep-alive',
        'Access-Control-Allow-Origin': '*',
      });

      const send = (payload: object) => {
        try {
          if (!reply.raw.writableEnded) {
            reply.raw.write(`data: ${JSON.stringify(payload)}\n\n`);
          }
        } catch { /* client disconnected early */ }
      };

      // 4. Initial connected event
      send({ type: 'connected', timestamp: new Date().toISOString(), projectId: getLinkedProjectId() });

      // 5. Keep-alive heartbeat
      const heartbeat = setInterval(() => {
        try { if (!reply.raw.writableEnded) reply.raw.write(': heartbeat\n\n'); } catch { /* noop */ }
      }, 15_000);

      // 6. Telemetry listeners
      const onMetric     = (metric: TelemetryMetric) => send({ type: 'metric',    data: metric, projectId: getLinkedProjectId() });
      const onEnvSync    = (envs: any)               => send({ type: 'env_sync',  data: envs,   projectId: getLinkedProjectId() });
      const onEnvAudit   = (logs: any)               => send({ type: 'env_audit', data: logs,   projectId: getLinkedProjectId() });
      const onSchemaSync = (schema: any)             => send({ type: 'schema_sync', data: schema, projectId: getLinkedProjectId() });

      telemetryEmitter.on('metric',    onMetric);
      telemetryEmitter.on('env_sync',  onEnvSync);
      telemetryEmitter.on('env_audit', onEnvAudit);
      telemetryEmitter.on('schema_sync', onSchemaSync);

      // Push current env/schema state to new client after a short delay
      setTimeout(() => telemetryEmitter.emit('client_connected'), 500);

      // 7. Cleanup on disconnect
      request.raw.on('close', () => {
        clearInterval(heartbeat);
        telemetryEmitter.off('metric',    onMetric);
        telemetryEmitter.off('env_sync',  onEnvSync);
        telemetryEmitter.off('env_audit', onEnvAudit);
        telemetryEmitter.off('schema_sync', onSchemaSync);
        try { reply.raw.end(); } catch { /* noop */ }
      });
    }
  });
};