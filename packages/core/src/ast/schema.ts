import { z } from 'zod';
import type { SchemaNode, TableNode, ColumnNode, PolicyNode, IndexNode } from './types.js';

export const DataTypeSchema = z.enum([
  'uuid',
  'text',
  'varchar',
  'integer',
  'bigint',
  'boolean',
  'timestamp',
  'timestamptz',
  'jsonb',
  'float',
  'serial',
]);

export const ForeignKeyActionSchema = z.enum([
  'cascade',
  'set null',
  'restrict',
  'no action',
]);

export const ForeignKeyReferenceSchema = z.object({
  table: z.string().min(1),
  column: z.string().min(1),
  onDelete: ForeignKeyActionSchema.optional(),
  onUpdate: ForeignKeyActionSchema.optional(),
});

export const DefaultValueSchema = z.union([
  z.string(),
  z.number(),
  z.boolean(),
  z.object({
    kind: z.literal('raw'),
    expression: z.string().min(1),
  }),
]);

export const ColumnNodeSchema: z.ZodType<ColumnNode> = z.object({
  name: z.string().min(1).regex(/^[a-zA-Z_][a-zA-Z0-9_]*$/, {
    message: 'Column name must be a valid SQL identifier',
  }),
  type: DataTypeSchema,
  length: z.number().int().positive().optional(),
  isPrimaryKey: z.boolean(),
  isNullable: z.boolean(),
  isUnique: z.boolean(),
  defaultValue: DefaultValueSchema.optional(),
  references: ForeignKeyReferenceSchema.optional(),
});

export const PolicyCommandSchema = z.enum([
  'all',
  'select',
  'insert',
  'update',
  'delete',
]);

export const PolicyNodeSchema: z.ZodType<PolicyNode> = z.object({
  name: z.string().min(1),
  for: PolicyCommandSchema,
  to: z.string().optional(),
  using: z.string().optional(),
  withCheck: z.string().optional(),
});

export const IndexMethodSchema = z.enum(['btree', 'hash', 'gin', 'gist']);

export const IndexNodeSchema: z.ZodType<IndexNode> = z.object({
  name: z.string().optional(),
  columns: z.array(z.string().min(1)).min(1),
  unique: z.boolean().optional(),
  method: IndexMethodSchema.optional(),
});

export const TableNodeSchema: z.ZodType<TableNode> = z.object({
  name: z.string().min(1).regex(/^[a-zA-Z_][a-zA-Z0-9_]*$/, {
    message: 'Table name must be a valid SQL identifier',
  }),
  columns: z.array(ColumnNodeSchema).min(1, {
    message: 'Table must have at least one column',
  }),
  policies: z.array(PolicyNodeSchema),
  indexes: z.array(IndexNodeSchema),
});

export const SchemaNodeSchema: z.ZodType<SchemaNode, z.ZodTypeDef, any> = z.object({
  version: z.string().default('1.0.0'),
  tables: z.array(TableNodeSchema),
});

export function validateSchemaAst(data: unknown): SchemaNode {
  return SchemaNodeSchema.parse(data);
}
