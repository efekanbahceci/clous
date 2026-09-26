import { describe, it, expect } from 'vitest';
import {
  schema,
  table,
  uuid,
  text,
  integer,
  boolean,
  OpenApiEmitter,
} from '../src/index.js';

describe('Clous Core - OpenApiEmitter', () => {
  it('should generate valid OpenAPI 3.0 specification for schema', () => {
    const products = table('products', {
      id: uuid('id').primaryKey().defaultRandom(),
      title: text('title').notNull(),
      price: integer('price').notNull(),
      inStock: boolean('in_stock').default(true),
    });

    const ast = schema({ tables: [products] });
    const emitter = new OpenApiEmitter();
    const spec = emitter.emit(ast, {
      title: 'Store API',
      description: 'Store dynamic REST API',
    });

    expect(spec.openapi).toBe('3.0.3');
    expect(spec.info.title).toBe('Store API');
    expect(spec.components.schemas).toHaveProperty('ProductsRow');
    expect(spec.components.schemas).toHaveProperty('ProductsInsert');
    expect(spec.components.schemas).toHaveProperty('ProductsUpdate');

    expect(spec.paths).toHaveProperty('/api/products');
    expect(spec.paths).toHaveProperty('/api/products/{id}');

    expect(spec.paths['/api/products']).toHaveProperty('get');
    expect(spec.paths['/api/products']).toHaveProperty('post');
    expect(spec.paths['/api/products/{id}']).toHaveProperty('get');
    expect(spec.paths['/api/products/{id}']).toHaveProperty('patch');
    expect(spec.paths['/api/products/{id}']).toHaveProperty('delete');
  });
});
