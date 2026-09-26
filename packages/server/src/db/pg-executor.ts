import pg from 'pg';
import type { TableNode } from '@clous/core';
import type { AuthContext } from '../types/context.js';
import type { FindManyQuery, QueryExecutor } from './executor.interface.js';

const { Pool } = pg;

export class PgExecutor implements QueryExecutor {
  private readonly pool: pg.Pool;
  private _isConnected: boolean = false;

  constructor(poolOrConfig: pg.Pool | pg.PoolConfig) {
    if (poolOrConfig instanceof Pool) {
      this.pool = poolOrConfig;
      this._isConnected = true;
    } else {
      this.pool = new Pool(poolOrConfig);
      this._isConnected = true;
    }
  }

  get isConnected(): boolean {
    return this._isConnected;
  }

  async query<T = any>(
    sql: string,
    params?: any[],
    context?: AuthContext
  ): Promise<T[]> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await this.setRlsContext(client, context);
      const result = await client.query(sql, params);
      await client.query('COMMIT');
      return result.rows as T[];
    } catch (err) {
      await client.query('ROLLBACK').catch(() => {});
      throw err;
    } finally {
      client.release();
    }
  }

  async findMany(
    table: TableNode,
    query: FindManyQuery,
    context?: AuthContext
  ): Promise<{ rows: any[]; total: number }> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await this.setRlsContext(client, context);

      const validColumns = new Set(table.columns.map((c) => c.name));

      // 1. Column Selection
      let selectClause = '*';
      if (query.select && query.select.length > 0) {
        const safeCols = query.select
          .filter((c) => validColumns.has(c))
          .map((c) => `"${c}"`);
        if (safeCols.length > 0) {
          selectClause = safeCols.join(', ');
        }
      }

      // 2. WHERE Filters
      const whereClauses: string[] = [];
      const params: any[] = [];
      let paramIdx = 1;

      if (query.filters) {
        for (const [key, value] of Object.entries(query.filters)) {
          if (validColumns.has(key) && value !== undefined) {
            whereClauses.push(`"${key}" = $${paramIdx++}`);
            params.push(value);
          }
        }
      }

      const whereSql =
        whereClauses.length > 0 ? `WHERE ${whereClauses.join(' AND ')}` : '';

      // Count query
      const countSql = `SELECT COUNT(*)::int as count FROM "${table.name}" ${whereSql}`;
      const countRes = await client.query(countSql, params);
      const total = countRes.rows[0]?.count ?? 0;

      // 3. Sorting
      let orderSql = '';
      if (query.sort && validColumns.has(query.sort)) {
        const direction = query.order === 'desc' ? 'DESC' : 'ASC';
        orderSql = `ORDER BY "${query.sort}" ${direction}`;
      }

      // 4. Pagination
      const limit = query.limit ?? 20;
      const offset = query.offset ?? ((query.page ?? 1) - 1) * limit;
      const paginationSql = `LIMIT $${paramIdx++} OFFSET $${paramIdx++}`;
      params.push(limit, offset);

      const dataSql = `SELECT ${selectClause} FROM "${table.name}" ${whereSql} ${orderSql} ${paginationSql}`;
      const dataRes = await client.query(dataSql, params);

      await client.query('COMMIT');
      return { rows: dataRes.rows, total };
    } catch (err) {
      await client.query('ROLLBACK').catch(() => {});
      throw err;
    } finally {
      client.release();
    }
  }

  async findById(
    table: TableNode,
    id: string | number,
    select?: string[],
    context?: AuthContext
  ): Promise<any | null> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await this.setRlsContext(client, context);

      const pkCol =
        table.columns.find((c) => c.isPrimaryKey)?.name ?? 'id';
      const validColumns = new Set(table.columns.map((c) => c.name));

      let selectClause = '*';
      if (select && select.length > 0) {
        const safeCols = select
          .filter((c) => validColumns.has(c))
          .map((c) => `"${c}"`);
        if (safeCols.length > 0) {
          selectClause = safeCols.join(', ');
        }
      }

      const sql = `SELECT ${selectClause} FROM "${table.name}" WHERE "${pkCol}" = $1 LIMIT 1`;
      const res = await client.query(sql, [id]);

      await client.query('COMMIT');
      return res.rows[0] ?? null;
    } catch (err) {
      await client.query('ROLLBACK').catch(() => {});
      throw err;
    } finally {
      client.release();
    }
  }

  async insert(
    table: TableNode,
    data: Record<string, any>,
    context?: AuthContext
  ): Promise<any> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await this.setRlsContext(client, context);

      const validColumns = new Set(table.columns.map((c) => c.name));
      const cols: string[] = [];
      const values: any[] = [];
      const placeholders: string[] = [];

      let idx = 1;
      for (const [key, value] of Object.entries(data)) {
        if (validColumns.has(key)) {
          cols.push(`"${key}"`);
          values.push(value);
          placeholders.push(`$${idx++}`);
        }
      }

      if (cols.length === 0) {
        const sql = `INSERT INTO "${table.name}" DEFAULT VALUES RETURNING *`;
        const res = await client.query(sql);
        await client.query('COMMIT');
        return res.rows[0];
      }

      const sql = `INSERT INTO "${table.name}" (${cols.join(
        ', '
      )}) VALUES (${placeholders.join(', ')}) RETURNING *`;
      const res = await client.query(sql, values);

      await client.query('COMMIT');
      return res.rows[0];
    } catch (err) {
      await client.query('ROLLBACK').catch(() => {});
      throw err;
    } finally {
      client.release();
    }
  }

  async update(
    table: TableNode,
    id: string | number,
    data: Record<string, any>,
    context?: AuthContext
  ): Promise<any | null> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await this.setRlsContext(client, context);

      const pkCol =
        table.columns.find((c) => c.isPrimaryKey)?.name ?? 'id';
      const validColumns = new Set(
        table.columns.filter((c) => !c.isPrimaryKey).map((c) => c.name)
      );

      const setClauses: string[] = [];
      const values: any[] = [];
      let idx = 1;

      for (const [key, value] of Object.entries(data)) {
        if (validColumns.has(key)) {
          setClauses.push(`"${key}" = $${idx++}`);
          values.push(value);
        }
      }

      if (setClauses.length === 0) {
        return this.findById(table, id, undefined, context);
      }

      values.push(id);
      const sql = `UPDATE "${table.name}" SET ${setClauses.join(
        ', '
      )} WHERE "${pkCol}" = $${idx} RETURNING *`;
      const res = await client.query(sql, values);

      await client.query('COMMIT');
      return res.rows[0] ?? null;
    } catch (err) {
      await client.query('ROLLBACK').catch(() => {});
      throw err;
    } finally {
      client.release();
    }
  }

  async delete(
    table: TableNode,
    id: string | number,
    context?: AuthContext
  ): Promise<any | null> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await this.setRlsContext(client, context);

      const pkCol =
        table.columns.find((c) => c.isPrimaryKey)?.name ?? 'id';
      const sql = `DELETE FROM "${table.name}" WHERE "${pkCol}" = $1 RETURNING *`;
      const res = await client.query(sql, [id]);

      await client.query('COMMIT');
      return res.rows[0] ?? null;
    } catch (err) {
      await client.query('ROLLBACK').catch(() => {});
      throw err;
    } finally {
      client.release();
    }
  }

  async close(): Promise<void> {
    await this.pool.end();
    this._isConnected = false;
  }

  private async setRlsContext(
    client: pg.PoolClient,
    context?: AuthContext
  ): Promise<void> {
    const sub = context?.sub ?? '';
    const role = context?.role ?? 'anon';
    const email = context?.email ?? '';
    const claimsJson = JSON.stringify(context?.claims ?? {});

    await client.query(
      `
      SELECT
        set_config('request.jwt.claim.sub', $1, true),
        set_config('request.jwt.claim.role', $2, true),
        set_config('request.jwt.claim.email', $3, true),
        set_config('request.jwt.claims', $4, true)
    `,
      [sub, role, email, claimsJson]
    );
  }
}
