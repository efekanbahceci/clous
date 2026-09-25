import { describe, it, expect } from 'vitest';
import {
  schema,
  table,
  uuid,
  text,
  boolean,
  integer,
  TsTypeEmitter,
} from '../src/index.js';

describe('Clous Core - TsTypeEmitter', () => {
  it('should emit correct TypeScript interfaces for Row, Insert, Update and Database', () => {
    const products = table('products', {
      id: uuid('id').primaryKey().defaultRandom(),
      name: text('name').notNull(),
      price: integer('price').notNull(),
      inStock: boolean('in_stock').notNull().default(true),
      description: text('description'),
    });

    const ast = schema({ tables: [products] });
    const emitter = new TsTypeEmitter();
    const tsCode = emitter.emit(ast, { includeHeader: false });

    // Verify Row type
    expect(tsCode).toContain('export interface ProductsRow {');
    expect(tsCode).toContain('id: string;');
    expect(tsCode).toContain('name: string;');
    expect(tsCode).toContain('price: number;');
    expect(tsCode).toContain('description: string | null;');

    // Verify Insert type (defaults and nullables are optional)
    expect(tsCode).toContain('export interface ProductsInsert {');
    expect(tsCode).toContain('id?: string;');
    expect(tsCode).toContain('in_stock?: boolean;');
    expect(tsCode).toContain('description?: string | null;');

    // Verify Update type
    expect(tsCode).toContain('export interface ProductsUpdate {');
    expect(tsCode).toContain('name?: string;');

    // Verify Database mapping
    expect(tsCode).toContain('export interface Database {');
    expect(tsCode).toContain('products: {');
    expect(tsCode).toContain('Row: ProductsRow;');
    expect(tsCode).toContain('Insert: ProductsInsert;');
    expect(tsCode).toContain('Update: ProductsUpdate;');
  });
});
