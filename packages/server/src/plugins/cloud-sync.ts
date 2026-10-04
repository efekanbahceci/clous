import fp from 'fastify-plugin';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { telemetryEmitter, type TelemetryMetric } from './telemetry.js';

/**
 * Cloud Sync
 * ----------
 * Pushes telemetry (HTTP traffic) and DB schema snapshots from the local runtime
 * directly to the Clous web platform, authenticated with the CLI access token.
 *
 * Why this exists: previously the *dashboard browser* on the developer's machine
 * relayed SSE events into the cloud. If the dashboard wasn't open on that exact
 * machine, nothing was persisted — so other devices never saw traffic or schemas.
 * Syncing server-to-server removes that dependency entirely.
 *
 * Fails soft: if the CLI isn't logged in / linked, or the platform is unreachable,
 * the local server keeps working and the dashboard falls back to live SSE only.
 */

interface SyncTarget {
  apiUrl: string;
  token: string;
  projectId: string;
}

const FLUSH_INTERVAL_MS = 2_000;
const MAX_BATCH = 100;
const MAX_QUEUE = 1_000;

function readJson(file: string): any | null {
  try {
    if (fs.existsSync(file)) return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch { /* ignore malformed files */ }
  return null;
}

function findProjectDir(): string | null {
  let current = process.cwd();
  while (true) {
    const p = path.join(current, '.clous');
    if (fs.existsSync(p) && fs.statSync(p).isDirectory()) return p;
    const parent = path.dirname(current);
    if (parent === current) return null;
    current = parent;
  }
}

// Mirrors packages/cli/src/config/paths.ts so both resolve the same credentials file.
function globalCredentialsPath(): string {
  if (process.env.CLOUS_CREDENTIALS_FILE) return process.env.CLOUS_CREDENTIALS_FILE;
  let dir: string;
  if (process.env.CLOUS_CONFIG_DIR) dir = process.env.CLOUS_CONFIG_DIR;
  else if (process.platform === 'win32') {
    dir = path.join(process.env.APPDATA || path.join(os.homedir(), 'AppData', 'Roaming'), 'clous');
  } else if (process.env.XDG_CONFIG_HOME) dir = path.join(process.env.XDG_CONFIG_HOME, 'clous');
  else dir = path.join(os.homedir(), '.config', 'clous');
  return path.join(dir, 'credentials.json');
}

function resolveTarget(): SyncTarget | null {
  const projectDir = findProjectDir();
  const project = projectDir ? readJson(path.join(projectDir, 'project.json')) : null;
  const projectId: string | undefined = project?.projectId;
  if (!projectId) return null;

  const creds =
    readJson(globalCredentialsPath()) ||
    (projectDir ? readJson(path.join(projectDir, 'credentials.json')) : null) ||
    {};

  const token: string | undefined = process.env.CLOUS_ACCESS_TOKEN || creds.token;
  let apiUrl: string = process.env.CLOUS_API_URL || creds.apiUrl || 'http://localhost:3000';
  if (!token) return null;

  apiUrl = apiUrl.replace(/\/+$/, '');
  return { apiUrl, token, projectId };
}

export const cloudSyncPlugin = fp(async (fastify) => {
  if (process.env.CLOUS_CLOUD_SYNC === 'false') return;
  if (process.env.VITEST || process.env.NODE_ENV === 'test') return;

  const queue: TelemetryMetric[] = [];
  let flushing = false;
  let lastWarnAt = 0;
  let lastProjectId = '';

  const warn = (msg: string) => {
    // Rate-limit warnings so an offline platform doesn't flood the terminal.
    if (Date.now() - lastWarnAt > 60_000) {
      lastWarnAt = Date.now();
      console.warn(`[CloudSync] ${msg}`);
    }
  };

  const getTrafficStorePath = () => {
    const p = findProjectDir();
    return p ? path.join(p, 'traffic.json') : null;
  };

  const loadLocalTraffic = () => {
    const storePath = getTrafficStorePath();
    if (!storePath || !fs.existsSync(storePath)) return [];
    try {
      return JSON.parse(fs.readFileSync(storePath, 'utf8'));
    } catch {
      return [];
    }
  };

  const saveLocalTraffic = (metrics: TelemetryMetric[]) => {
    const storePath = getTrafficStorePath();
    if (!storePath) return;
    try {
      // Keep only the last MAX_QUEUE items to prevent infinite growth
      const toSave = metrics.slice(-MAX_QUEUE);
      fs.writeFileSync(storePath, JSON.stringify(toSave), 'utf8');
    } catch { /* ignore */ }
  };

  const post = async (target: SyncTarget, urlPath: string, method: string, body: unknown) => {
    const res = await fetch(`${target.apiUrl}${urlPath}`, {
      method,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${target.token}`,
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(8_000),
    });
    if (!res.ok) throw new Error(`${method} ${urlPath} -> HTTP ${res.status}`);
  };

  const flush = async () => {
    if (flushing) return;
    
    // Re-resolved each flush so `clous link` / `clous login` take effect without a restart.
    const target = resolveTarget();
    if (!target) {
      queue.length = 0;
      return;
    }

    // Project changed (e.g. unlink then link to a new project) or server just started? 
    // Migrate the historical local traffic to the current project!
    if (target.projectId !== lastProjectId) {
      const history = loadLocalTraffic();
      // Only enqueue if they aren't already in the queue
      const existingIds = new Set(queue.map(m => m.id));
      const newItems = history.filter((m: any) => !existingIds.has(m.id));
      queue.unshift(...newItems);
      if (queue.length > MAX_QUEUE) queue.splice(0, queue.length - MAX_QUEUE);
      lastProjectId = target.projectId;
    }

    if (queue.length === 0) return;

    flushing = true;
    const batch = queue.splice(0, MAX_BATCH);
    try {
      await post(target, `/api/projects/${encodeURIComponent(target.projectId)}/traffic`, 'POST', {
        logs: batch,
      });
    } catch (e: any) {
      // Put the batch back (bounded) so a short outage doesn't lose data.
      queue.unshift(...batch);
      if (queue.length > MAX_QUEUE) queue.splice(MAX_QUEUE); // remove from end if over limit
      warn(`Traffic sync failed: ${e.message}`);
    } finally {
      flushing = false;
    }
  };

  const onMetric = (metric: TelemetryMetric) => {
    queue.push(metric);
    if (queue.length > MAX_QUEUE) queue.shift();
    
    // Save to local file so it persists across restarts
    const history = loadLocalTraffic();
    history.push(metric);
    saveLocalTraffic(history);

    if (queue.length >= MAX_BATCH) void flush();
  };

  let lastSchemaHash = '';
  const onSchema = async (schema: any) => {
    const target = resolveTarget();
    if (!target) return;
    const { timestamp: _ts, ...stable } = schema || {};
    const hash = JSON.stringify(stable);
    if (hash === lastSchemaHash) return; // unchanged — skip redundant uploads
    try {
      await post(target, `/api/projects/${encodeURIComponent(target.projectId)}/schema`, 'PUT', {
        dbSchema: schema,
      });
      lastSchemaHash = hash;
    } catch (e: any) {
      warn(`Schema sync failed: ${e.message}`);
    }
  };

  telemetryEmitter.on('metric', onMetric);
  telemetryEmitter.on('schema_sync', onSchema);
  const timer = setInterval(() => void flush(), FLUSH_INTERVAL_MS);
  timer.unref();

  fastify.addHook('onClose', async () => {
    clearInterval(timer);
    telemetryEmitter.off('metric', onMetric);
    telemetryEmitter.off('schema_sync', onSchema);
    await flush();
  });
});
