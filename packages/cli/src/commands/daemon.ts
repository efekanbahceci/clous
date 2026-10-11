import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { resolveSchemaPath } from '../config/paths.js';
import { ProjectConfigManager } from '../config/project.js';
import { CredentialsManager } from '../config/credentials.js';

export async function daemonCommand(action: 'start' | 'stop' | 'run'): Promise<void> {
  const cwd = process.cwd();
  const pidFile = path.join(cwd, '.clous', 'daemon.pid');

  if (action === 'start') {
    if (fs.existsSync(pidFile)) {
      console.log('Daemon is already running.');
      return;
    }
    const binPath = path.resolve(new URL(import.meta.url).pathname, '../../bin.js');
    const child = spawn(process.execPath, [binPath, 'daemon', 'run'], {
      detached: true,
      stdio: 'ignore',
      cwd: cwd,
    });
    child.unref();
    fs.writeFileSync(pidFile, child.pid?.toString() || '');
    console.log('Clous background service (Daemon) started.');
    return;
  }

  if (action === 'stop') {
    if (fs.existsSync(pidFile)) {
      try {
        const pid = parseInt(fs.readFileSync(pidFile, 'utf8'), 10);
        process.kill(pid);
      } catch (e) {
        // ignore
      }
      fs.unlinkSync(pidFile);
      console.log('Clous background service stopped.');
    } else {
      console.log('No running daemon found.');
    }
    return;
  }

  if (action === 'run') {
    // Daemon logic (Runs only in the background)
    const project = ProjectConfigManager.load(cwd);
    const creds = CredentialsManager.load();
    if (!project || !creds) process.exit(1);

    const token = creds.token;
    const apiUrl = creds.apiUrl || 'https://clous.dev';
    const projectId = project.projectId;

    const pushEnv = async () => {
      const envPath = path.join(cwd, '.env');
      if (!fs.existsSync(envPath)) return;
      
      const content = fs.readFileSync(envPath, 'utf8');
      const envs = [];
      for (const line of content.split('\n')) {
        const trimmed = line.trim();
        if (trimmed && !trimmed.startsWith('#') && trimmed.includes('=')) {
          const [key, ...rest] = trimmed.split('=');
          envs.push({ key: key.trim(), value: rest.join('=').trim() });
        }
      }
      
      try {
        await fetch(`${apiUrl}/api/projects/${projectId}/env/sync`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
          body: JSON.stringify({ envs })
        });
      } catch (e) {}
    };

    const pushSchema = async () => {
       // In the future, schema.ts can be compiled and sent,
       // but for now env sync is sufficient
    };

    // Initial scan
    await pushEnv();

    // Watcher
    const envPath = path.join(cwd, '.env');
    if (fs.existsSync(envPath)) {
      fs.watchFile(envPath, { interval: 2000 }, async (curr, prev) => {
        if (curr.mtime !== prev.mtime) {
          await pushEnv();
        }
      });
    }

    // Keep process alive
    setInterval(() => {}, 1000 * 60 * 60);
  }
}
