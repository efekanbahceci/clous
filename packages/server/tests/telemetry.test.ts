import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { schema, table, uuid, text } from '@clous/core';
import { createClousServer } from '../src/server.js';
import { telemetryEmitter, type TelemetryMetric } from '../src/plugins/telemetry.js';

/** Resolves with the next metric emitted for `path`. */
function nextMetric(path: string): Promise<TelemetryMetric> {
  return new Promise((resolve) => {
    const listener = (metric: TelemetryMetric) => {
      if (metric.path !== path) return;
      telemetryEmitter.off('metric', listener);
      resolve(metric);
    };
    telemetryEmitter.on('metric', listener);
  });
}

describe('Telemetry Plugin & SSE', () => {
  let app: FastifyInstance;

  beforeAll(async () => {
    const notes = table('notes', {
      id: uuid('id').primaryKey().defaultRandom(),
      title: text('title').notNull(),
      password: text('password'),
    });

    app = await createClousServer({
      schema: schema({ version: '1.0.0', tables: [notes] }),
      database: { provider: 'memory' },
      admin: { secret: 'super-secret' },
    });
    await app.ready();
  });

  afterAll(async () => {
    await app?.close();
  });

  it('emits a metric with timing and status for each request', async () => {
    const pending = nextMetric('/api/notes');
    const res = await app.inject({ method: 'GET', url: '/api/notes' });
    const metric = await pending;

    expect(metric.method).toBe('GET');
    expect(metric.status).toBe(res.statusCode);
    expect(metric.duration).toBeGreaterThanOrEqual(0);
    expect(typeof metric.id).toBe('string');
  });

  it('captures request/response headers and bodies', async () => {
    const pending = nextMetric('/api/notes');
    const res = await app.inject({
      method: 'POST',
      url: '/api/notes',
      headers: { 'content-type': 'application/json', 'x-trace-id': 'abc123' },
      payload: { title: 'hello' },
    });
    const metric = await pending;

    expect(metric.requestHeaders?.['x-trace-id']).toBe('abc123');
    expect(metric.requestBody).toEqual({ title: 'hello' });
    expect(metric.responseHeaders?.['content-type']).toContain('application/json');
    expect(metric.responseBody).toEqual(JSON.parse(res.body));
  });

  it('redacts sensitive headers and body fields', async () => {
    const pending = nextMetric('/api/notes');
    await app.inject({
      method: 'POST',
      url: '/api/notes',
      headers: {
        'content-type': 'application/json',
        authorization: 'Bearer real-token',
        cookie: 'session=xyz',
      },
      payload: { title: 'secret note', password: 'hunter2' },
    });
    const metric = await pending;

    expect(metric.requestHeaders?.authorization).toBe('[REDACTED]');
    expect(metric.requestHeaders?.cookie).toBe('[REDACTED]');
    expect((metric.requestBody as any).password).toBe('[REDACTED]');
    expect((metric.requestBody as any).title).toBe('secret note');
  });

  it('blocks unauthorized access to the SSE stream', async () => {
    const res = await app.inject({ method: 'GET', url: '/api/_clous/telemetry/stream' });
    expect(res.statusCode).toBe(401);
  });

  it('allows authorized access to the SSE stream', async () => {
    // The stream never ends, so use a real socket and abort after reading headers.
    const address = await app.listen({ port: 0, host: '127.0.0.1' });
    const controller = new AbortController();
    const res = await fetch(`${address}/api/_clous/telemetry/stream`, {
      headers: { authorization: 'Bearer super-secret' },
      signal: controller.signal,
    });

    expect(res.status).toBe(200);
    expect(res.headers.get('content-type')).toContain('text/event-stream');
    controller.abort();
  });
});
