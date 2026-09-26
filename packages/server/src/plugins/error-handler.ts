import type { FastifyError, FastifyInstance } from 'fastify';
import { ZodError } from 'zod';

export function setupErrorHandler(fastify: FastifyInstance) {
  fastify.setErrorHandler((error: FastifyError | Error, _req, reply) => {
    // 1. Zod Validation Errors
    if (error instanceof ZodError) {
      return reply.status(400).send({
        statusCode: 400,
        error: 'Bad Request',
        message: 'Schema validation failed',
        issues: error.issues.map((i) => ({
          path: i.path.join('.'),
          message: i.message,
          code: i.code,
        })),
      });
    }

    // 2. Fastify Validation Errors
    if ('validation' in error && error.validation) {
      return reply.status(400).send({
        statusCode: 400,
        error: 'Bad Request',
        message: error.message,
        validation: error.validation,
      });
    }

    // 3. PostgreSQL Specific Errors
    const pgError = error as any;
    if (pgError.code) {
      // 23505: Unique constraint violation
      if (pgError.code === '23505') {
        return reply.status(409).send({
          statusCode: 409,
          error: 'Conflict',
          message: 'A record with this identifier already exists',
          detail: pgError.detail,
        });
      }
      // 23503: Foreign key violation
      if (pgError.code === '23503') {
        return reply.status(400).send({
          statusCode: 400,
          error: 'Bad Request',
          message: 'Foreign key constraint violation',
          detail: pgError.detail,
        });
      }
      // 42501: Insufficient privilege / RLS violation
      if (pgError.code === '42501') {
        return reply.status(403).send({
          statusCode: 403,
          error: 'Forbidden',
          message: 'Permission denied by Row Level Security (RLS) policy',
        });
      }
    }

    // 4. Default / Internal Server Error
    const statusCode = (error as any).statusCode || 500;
    const message = statusCode === 500 ? 'Internal Server Error' : error.message;

    if (statusCode === 500) {
      fastify.log.error(error);
    }

    return reply.status(statusCode).send({
      statusCode,
      error: error.name || 'Error',
      message,
    });
  });
}
