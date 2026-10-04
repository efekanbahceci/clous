import fp from 'fastify-plugin';
import { EventEmitter } from 'events';
import crypto from 'crypto';
import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';

export interface TelemetryMetric {
  id: string;
  method: string;
  path: string;
  url?: string;
  status: number;
  duration: number;
  timestamp: string;
  ip?: string;
  requestHeaders?: Record<string, string>;
  responseHeaders?: Record<string, string>;
  requestBody?: unknown;
  responseBody?: unknown;
}

// Global emitter for telemetry events
export const telemetryEmitter = new EventEmitter();
// Allow many concurrent Dashboard connections
telemetryEmitter.setMaxListeners(100);

/** Max bytes kept per captured body. Larger payloads are truncated. */
const MAX_BODY_BYTES = 16 * 1024;
const REDACTED = '[REDACTED]';

/** Headers that must never leave the developer's machine. */
const SENSITIVE_HEADERS = new Set([
  'authorization',
  'proxy-authorization',
  'cookie',
  'set-cookie',
  'x-api-key',
  'x-auth-token',
  'x-clous-secret',
]);

/** Body keys whose values are masked (matched case-insensitively, substring). */
const SENSITIVE_KEY_PATTERN = /pass(word)?|secret|token|api[-_]?key|private[-_]?key|credit[-_]?card|cvv|ssn/i;

function sanitizeHeaders(headers: Record<string, unknown> | undefined): Record<string, string> {
  const out: Record<string, string> = {};
  if (!headers) return out;
  for (const [key, value] of Object.entries(headers)) {
    if (value === undefined) continue;
    const k = key.toLowerCase();
    out[k] = SENSITIVE_HEADERS.has(k)
      ? REDACTED
      : Array.isArray(value) ? value.join(', ') : String(value);
  }
  return out;
}

function redactDeep(value: unknown, depth = 0): unknown {
  if (depth > 8 || value === null || typeof value !== 'object') return value;
  if (Array.isArray(value)) return value.slice(0, 50).map((v) => redactDeep(v, depth + 1));
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
    out[k] = SENSITIVE_KEY_PATTERN.test(k) ? REDACTED : redactDeep(v, depth + 1);
  }
  return out;
}

/** Turns a raw payload into a JSON-safe, redacted, size-limited value. */
function captureBody(payload: unknown, contentType?: string): unknown {
  if (payload === undefined || payload === null || payload === '') return null;

  let text: string | null = null;
  if (typeof payload === 'string') text = payload;
  else if (Buffer.isBuffer(payload)) text = payload.toString('utf8');
  else if (typeof payload === 'object') {
    // Streams cannot be read without consuming them.
    if (typeof (payload as any).pipe === 'function') return '[stream]';
    return redactDeep(payload);
  } else return payload;

  const ct = (contentType || '').toLowerCase();
  const isTextual = !ct || ct.includes('json') || ct.startsWith('text/') || ct.includes('xml') || ct.includes('x-www-form-urlencoded');
  if (!isTextual) return `[binary ${ct || 'content'} • ${Buffer.byteLength(text)} bytes]`;

  if (Buffer.byteLength(text) > MAX_BODY_BYTES) {
    return `${text.slice(0, MAX_BODY_BYTES)}… [truncated]`;
  }

  if (ct.includes('json') || /^\s*[{[]/.test(text)) {
    try { return redactDeep(JSON.parse(text)); } catch { /* fall through to raw text */ }
  }
  return text;
}

export const telemetryPlugin = fp(async (fastify: FastifyInstance) => {
  fastify.addHook('onRequest', (request: FastifyRequest, _reply: FastifyReply, done) => {
    // Record start time using high-resolution real time
    (request as any).telemetryStartTime = process.hrtime.bigint();
    done();
  });

  // onSend is the only hook that sees the serialized response payload.
  fastify.addHook('onSend', (request: FastifyRequest, reply: FastifyReply, payload, done) => {
    try {
      (request as any).telemetryResponseBody = captureBody(
        payload,
        String(reply.getHeader('content-type') ?? '')
      );
    } catch { /* never break the response because of telemetry */ }
    done(null, payload);
  });

  fastify.addHook('onResponse', (request: FastifyRequest, reply: FastifyReply, done) => {
    const startTime = (request as any).telemetryStartTime;
    if (startTime) {
      const endTime = process.hrtime.bigint();
      // Calculate duration in milliseconds
      const durationMs = Number(endTime - startTime) / 1_000_000;

      // Do not log the telemetry stream endpoint itself to prevent feedback loops
      const path = request.routeOptions?.url || request.url;
      if (!path.includes('/telemetry/stream')) {
        try {
          const metric: TelemetryMetric = {
            id: crypto.randomUUID(),
            method: request.method,
            path,
            url: request.url,
            status: reply.statusCode,
            duration: Math.round(durationMs * 100) / 100,
            timestamp: new Date().toISOString(),
            ip: request.ip,
            requestHeaders: sanitizeHeaders(request.headers as Record<string, unknown>),
            responseHeaders: sanitizeHeaders(reply.getHeaders() as Record<string, unknown>),
            requestBody: captureBody(request.body, String(request.headers['content-type'] ?? '')),
            responseBody: (request as any).telemetryResponseBody ?? null,
          };

          telemetryEmitter.emit('metric', metric);
        } catch (e: any) {
          fastify.log.warn(`[Telemetry] Failed to capture metric: ${e?.message}`);
        }
      }
    }
    done();
  });
});
