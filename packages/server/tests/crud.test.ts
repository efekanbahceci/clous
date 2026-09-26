import { describe, it, expect, afterAll, beforeAll } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { schema, table, uuid, text, integer, boolean } from '@clous/core';
import { createClousServer } from '../src/index.js';

describe('Clous Server - Dynamic CRUD Endpoints', () => {
  let app: FastifyInstance;

  beforeAll(async () => {
    const products = table('products', {
      id: uuid('id').primaryKey().defaultRandom(),
      name: text('name').notNull(),
      category: text('category').default('general'),
      price: integer('price').notNull(),
      inStock: boolean('in_stock').default(true),
    });

    const testSchema = schema({
      tables: [products],
    });

    app = await createClousServer({
      schema: testSchema,
      database: { provider: 'memory' },
    });

    await app.ready();
  });

  afterAll(async () => {
    await app.close();
  });

  it('should reject insertion if required field is missing', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/products',
      payload: {
        category: 'electronics',
      },
    });

    expect(res.statusCode).toBe(400);
    const body = JSON.parse(res.payload);
    expect(body.message).toContain('required');
  });

  it('should successfully create a new record via POST /api/:table', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/products',
      payload: {
        name: 'Wireless Keyboard',
        category: 'electronics',
        price: 4999,
        in_stock: true,
      },
    });

    expect(res.statusCode).toBe(201);
    const body = JSON.parse(res.payload);
    expect(body.data).toHaveProperty('id');
    expect(body.data.name).toBe('Wireless Keyboard');
    expect(body.data.price).toBe(4999);
  });

  it('should list records with pagination via GET /api/:table', async () => {
    // Insert another record
    await app.inject({
      method: 'POST',
      url: '/api/products',
      payload: {
        name: 'Gaming Mouse',
        category: 'electronics',
        price: 2999,
      },
    });

    const res = await app.inject({
      method: 'GET',
      url: '/api/products?page=1&limit=10',
    });

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.payload);
    expect(Array.isArray(body.data)).toBe(true);
    expect(body.data.length).toBeGreaterThanOrEqual(2);
    expect(body.pagination.page).toBe(1);
    expect(body.pagination.limit).toBe(10);
    expect(body.pagination.total).toBeGreaterThanOrEqual(2);
  });

  it('should filter records by query parameter', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/products?name=Wireless Keyboard',
    });

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.payload);
    expect(body.data).toHaveLength(1);
    expect(body.data[0].name).toBe('Wireless Keyboard');
  });

  it('should retrieve a single record via GET /api/:table/:id', async () => {
    // 1. Create product
    const createRes = await app.inject({
      method: 'POST',
      url: '/api/products',
      payload: {
        name: 'Monitor Stand',
        price: 1999,
      },
    });
    const createdId = JSON.parse(createRes.payload).data.id;

    // 2. Fetch by ID
    const getRes = await app.inject({
      method: 'GET',
      url: `/api/products/${createdId}`,
    });

    expect(getRes.statusCode).toBe(200);
    const body = JSON.parse(getRes.payload);
    expect(body.data.id).toBe(createdId);
    expect(body.data.name).toBe('Monitor Stand');
  });

  it('should update a record via PATCH /api/:table/:id', async () => {
    // 1. Create product
    const createRes = await app.inject({
      method: 'POST',
      url: '/api/products',
      payload: {
        name: 'Desk Pad',
        price: 1500,
      },
    });
    const createdId = JSON.parse(createRes.payload).data.id;

    // 2. Update price
    const patchRes = await app.inject({
      method: 'PATCH',
      url: `/api/products/${createdId}`,
      payload: {
        price: 1200,
      },
    });

    expect(patchRes.statusCode).toBe(200);
    const body = JSON.parse(patchRes.payload);
    expect(body.data.price).toBe(1200);
    expect(body.data.name).toBe('Desk Pad');
  });

  it('should delete a record via DELETE /api/:table/:id', async () => {
    // 1. Create product
    const createRes = await app.inject({
      method: 'POST',
      url: '/api/products',
      payload: {
        name: 'Old Cable',
        price: 500,
      },
    });
    const createdId = JSON.parse(createRes.payload).data.id;

    // 2. Delete product
    const delRes = await app.inject({
      method: 'DELETE',
      url: `/api/products/${createdId}`,
    });

    expect(delRes.statusCode).toBe(200);

    // 3. Confirm 404
    const getRes = await app.inject({
      method: 'GET',
      url: `/api/products/${createdId}`,
    });
    expect(getRes.statusCode).toBe(404);
  });
});
