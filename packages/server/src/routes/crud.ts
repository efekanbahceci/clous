import type { FastifyPluginAsync } from 'fastify';
import type { ColumnNode, TableNode } from '@clous/core';
import type { QueryExecutor } from '../db/executor.interface.js';

export const crudRoutes: FastifyPluginAsync<{
  tables: TableNode[];
  executor: QueryExecutor;
}> = async (fastify, opts) => {
  const { tables, executor } = opts;

  for (const table of tables) {
    const basePath = `/api/${table.name}`;
    const itemPath = `/api/${table.name}/:id`;

    // 1. GET /api/:table - List with pagination, filters, sorting, select
    fastify.get(basePath, async (req, reply) => {
      const query = req.query as Record<string, any>;
      const page = Math.max(1, parseInt(query.page, 10) || 1);
      const limit = Math.min(100, Math.max(1, parseInt(query.limit, 10) || 20));
      const sort = query.sort ? String(query.sort) : undefined;
      const order = query.order === 'desc' ? 'desc' : 'asc';
      const select = query.select
        ? String(query.select)
            .split(',')
            .map((s) => s.trim())
            .filter(Boolean)
        : undefined;

      // Extract column-specific filters
      const reservedParams = new Set([
        'page',
        'limit',
        'offset',
        'sort',
        'order',
        'select',
      ]);
      const filters: Record<string, any> = {};

      for (const [key, value] of Object.entries(query)) {
        if (!reservedParams.has(key)) {
          filters[key] = value;
        }
      }

      const { rows, total } = await executor.findMany(
        table,
        {
          page,
          limit,
          sort,
          order,
          select,
          filters,
        },
        req.auth
      );

      const totalPages = Math.ceil(total / limit);

      return reply.send({
        data: rows,
        pagination: {
          total,
          page,
          limit,
          totalPages,
        },
      });
    });

    // 2. GET /api/:table/:id - Retrieve single record
    fastify.get(itemPath, async (req, reply) => {
      const { id } = req.params as { id: string };
      const query = req.query as Record<string, any>;
      const select = query.select
        ? String(query.select)
            .split(',')
            .map((s) => s.trim())
            .filter(Boolean)
        : undefined;

      const record = await executor.findById(table, id, select, req.auth);
      if (!record) {
        return reply.status(404).send({
          statusCode: 404,
          error: 'Not Found',
          message: `Record with id "${id}" not found in table "${table.name}"`,
        });
      }

      return reply.send({ data: record });
    });

    // 3. POST /api/:table - Create new record
    fastify.post(basePath, async (req, reply) => {
      const body = (req.body as Record<string, any>) || {};

      // Validate required columns
      validateInsertPayload(table, body);

      const created = await executor.insert(table, body, req.auth);
      return reply.status(201).send({ data: created });
    });

    // 4. PATCH /api/:table/:id - Update existing record
    fastify.patch(itemPath, async (req, reply) => {
      const { id } = req.params as { id: string };
      const body = (req.body as Record<string, any>) || {};

      validateUpdatePayload(table, body);

      const updated = await executor.update(table, id, body, req.auth);
      if (!updated) {
        return reply.status(404).send({
          statusCode: 404,
          error: 'Not Found',
          message: `Record with id "${id}" not found or update not permitted`,
        });
      }

      return reply.send({ data: updated });
    });

    // 5. DELETE /api/:table/:id - Delete record
    fastify.delete(itemPath, async (req, reply) => {
      const { id } = req.params as { id: string };

      const deleted = await executor.delete(table, id, req.auth);
      if (!deleted) {
        return reply.status(404).send({
          statusCode: 404,
          error: 'Not Found',
          message: `Record with id "${id}" not found or deletion not permitted`,
        });
      }

      return reply.send({
        data: deleted,
        message: `Record with id "${id}" successfully deleted`,
      });
    });
  }
};

function validateInsertPayload(table: TableNode, body: Record<string, any>) {
  const tableColumns = new Map<string, ColumnNode>();
  for (const col of table.columns) {
    tableColumns.set(col.name, col);
  }

  // Check required columns
  for (const col of table.columns) {
    const isRequired =
      !col.isNullable &&
      col.defaultValue === undefined &&
      col.type !== 'serial' &&
      !col.isPrimaryKey;

    if (isRequired && (body[col.name] === undefined || body[col.name] === null)) {
      const err = new Error(
        `Field "${col.name}" is required on table "${table.name}"`
      );
      (err as any).statusCode = 400;
      throw err;
    }
  }

  // Check for unknown columns
  for (const key of Object.keys(body)) {
    if (!tableColumns.has(key)) {
      const err = new Error(
        `Unknown field "${key}" provided for table "${table.name}"`
      );
      (err as any).statusCode = 400;
      throw err;
    }
  }
}

function validateUpdatePayload(table: TableNode, body: Record<string, any>) {
  const tableColumns = new Map<string, ColumnNode>();
  for (const col of table.columns) {
    tableColumns.set(col.name, col);
  }

  for (const key of Object.keys(body)) {
    if (!tableColumns.has(key)) {
      const err = new Error(
        `Unknown field "${key}" provided for table "${table.name}"`
      );
      (err as any).statusCode = 400;
      throw err;
    }
    const col = tableColumns.get(key)!;
    if (col.isPrimaryKey) {
      const err = new Error(`Primary key "${key}" cannot be updated directly`);
      (err as any).statusCode = 400;
      throw err;
    }
  }
}
