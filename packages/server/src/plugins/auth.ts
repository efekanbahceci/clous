import type { FastifyPluginAsync } from 'fastify';
import fastifyJwt from '@fastify/jwt';
import type { AuthConfig } from '../config.js';

export const authPlugin: FastifyPluginAsync<{ config?: AuthConfig }> = async (
  fastify,
  opts
) => {
  const { config } = opts;
  const secret = config?.jwtSecret || 'clous-development-insecure-secret-key-32-bytes!';
  const isRequired = config?.required ?? false;

  await fastify.register(fastifyJwt, {
    secret,
  });

  fastify.addHook('onRequest', async (req, reply) => {
    // Default to anonymous context
    req.auth = {
      role: 'anon',
      claims: {},
    };

    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const decoded = await req.jwtVerify<Record<string, any>>();
        req.auth = {
          sub: decoded.sub,
          role: decoded.role || 'authenticated',
          email: decoded.email,
          claims: decoded,
        };
      } catch (err: any) {
        if (isRequired) {
          return reply.status(401).send({
            statusCode: 401,
            error: 'Unauthorized',
            message: 'Invalid or expired token',
          });
        }
      }
    } else if (isRequired) {
      return reply.status(401).send({
        statusCode: 401,
        error: 'Unauthorized',
        message: 'Missing Bearer authorization token',
      });
    }
  });
};
