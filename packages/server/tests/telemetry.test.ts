import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { createClousServer } from '../src/server.js';
import type { FastifyInstance } from 'fastify';
import { telemetryEmitter } from '../src/plugins/telemetry.js';

describe('Telemetry Plugin & SSE', () => {
  let app: FastifyInstance;

  beforeAll(async () => {
    app = await createClousServer({
      schema: {
        tables: {
          test: {
            columns: { id: { type: 'uuid', primaryKey: true } },
          },
        },
      },
      database: { provider: 'memory' },
      admin: { secret: 'super-secret' },
    });
    await app.ready();
  });

  afterAll(async () => {
    await app.close();
  });

  it('should generate telemetry metric on request', async () => {
    return new Promise<void>(async (resolve, reject) => {
      const listener = (metric: any) => {
        try {
          expect(metric.path).toBe('/api/test');
          expect(metric.statusCode).toBe(200);
          expect(metric.durationMs).toBeGreaterThanOrEqual(0);
          telemetryEmitter.off('metric', listener);
          resolve();
        } catch (e) {
          reject(e);
        }
      };

      telemetryEmitter.on('metric', listener);

      const res = await app.inject({
        method: 'GET',
        url: '/api/test',
      });

      expect(res.statusCode).toBe(200);
    });
  });

  it('should block unauthorized access to SSE stream', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/_clous/telemetry/stream',
    });

    expect(res.statusCode).toBe(401);
  });

  it('should allow authorized access to SSE stream', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/_clous/telemetry/stream',
      headers: {
        authorization: 'Bearer super-secret',
      },
    });

    // Since we don't hold the connection in inject if we don't consume,
    // the stream connects and returns 200 chunked.
    expect(res.statusCode).toBe(200);
    expect(res.headers['content-type']).toContain('text/event-stream');
  });
});
