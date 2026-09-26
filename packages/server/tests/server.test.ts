import { describe, it, expect, afterAll, beforeAll } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { schema, table, uuid, text, integer, boolean } from '@clous/core';
import { createClousServer } from '../src/index.js';

describe('Clous Server - Core & Meta Endpoints', () => {
  let app: FastifyInstance;

  beforeAll(async () => {
    const products = table('products', {
      id: uuid('id').primaryKey().defaultRandom(),
      name: text('name').notNull(),
      price: integer('price').notNull(),
      inStock: boolean('in_stock').default(true),
    });

    const testSchema = schema({
      version: '1.2.0',
      tables: [products],
    });

    app = await createClousServer({
      schema: testSchema,
      database: { provider: 'memory' },
      admin: { secret: 'supersecret', allowSchemaUpdates: true },
    });

    await app.ready();
  });

  afterAll(async () => {
    await app.close();
  });

  it('should return 200 on /api/_clous/health', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/_clous/health',
    });

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.payload);
    expect(body.status).toBe('healthy');
    expect(body.version).toBe('1.2.0');
    expect(body.tablesCount).toBe(1);
  });

  it('should return current schema on /api/_clous/schema for Web Panel', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/_clous/schema',
    });

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.payload);
    expect(body.data.tables[0].name).toBe('products');
    expect(body.data.tables[0].columns).toHaveLength(4);
  });

  it('should return table metadata on /api/_clous/meta', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/_clous/meta',
    });

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.payload);
    expect(body.tables[0].name).toBe('products');
    expect(body.tables[0].primaryKey).toBe('id');
    expect(body.tables[0].columnsCount).toBe(4);
  });

  it('should serve dynamic OpenAPI 3.0 specification on /api/_clous/openapi.json', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/_clous/openapi.json',
    });

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.payload);
    expect(body.openapi).toBe('3.0.3');
    expect(body.paths).toHaveProperty('/api/products');
    expect(body.paths).toHaveProperty('/api/products/{id}');
  });

  it('should serve HTML documentation on /api/_clous/docs', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/_clous/docs',
    });

    expect(res.statusCode).toBe(200);
    expect(res.headers['content-type']).toContain('text/html');
    expect(res.payload).toContain('Clous API Reference');
  });
});
