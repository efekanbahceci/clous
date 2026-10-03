import { ProjectConfigManager } from '../config/project.js';
import { logger } from '../utils/logger.js';
import { ansi } from '../utils/ansi.js';
import { ui } from '../utils/ui.js';
import * as fs from 'fs';
import * as path from 'path';

import { getProjectConfigPath, getProjectConfigDir } from '../config/paths.js';
import { CredentialsManager } from '../config/credentials.js';

export interface UnlinkOptions {
  cwd?: string;
  projectId?: string;
}

export async function unlinkCommand(options: UnlinkOptions): Promise<void> {
  const token = CredentialsManager.getToken();
  const apiBase = CredentialsManager.getApiUrl();

  // 1. If explicit ID provided, force remote unlink
  if (options.projectId) {
    if (!token) {
      logger.error('You must be logged in to force unlink a remote project.');
      return;
    }
    try {
      const endpoint = `${apiBase}/api/projects/${options.projectId}/unlink`;
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      });
      if (!res.ok) {
        throw new Error(`API Error (${res.status})`);
      }
      console.log('');
      ui.box({
        title: 'Remote Project Unlinked',
        borderColor: ansi.yellow,
        minWidth: 60,
        lines: [
          `Target ID     ${ansi.bold(options.projectId)}`,
          `Status        ${ansi.red('Disconnected from Web Panel workspace')}`
        ],
      });
      console.log('');
    } catch (e: any) {
      logger.error(`Failed to unlink remote project: ${e.message}`);
    }
    return;
  }

  // 2. Normal local unlink
  const cwd = options.cwd || process.cwd();
  const configPath = getProjectConfigPath(cwd);
  
  let configData: any = null;
  if (!fs.existsSync(configPath)) {
    logger.warn('No active project link found in this directory. If you want to force unlink a remote project, use "clous unlink <project_id>".');
    return;
  }
  
  try {
    const raw = fs.readFileSync(configPath, 'utf8');
    configData = JSON.parse(raw);
  } catch (e) {}

  try {
    fs.unlinkSync(configPath);
    const clousDir = path.dirname(configPath);
    if (fs.readdirSync(clousDir).length === 0) {
      fs.rmdirSync(clousDir);
    }
  } catch (error) {
    logger.error(`Failed to remove local link: ${error}`);
    return;
  }
  
  if (token && configData && configData.projectId) {
    try {
      const endpoint = `${apiBase}/api/projects/${configData.projectId}/unlink`;
      await fetch(endpoint, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      });
    } catch (e) {
      // ignore
    }
  }

  console.log('');
  ui.box({
    title: 'Project Unlinked',
    borderColor: ansi.yellow,
    minWidth: 60,
    lines: [
      `Status        ${ansi.red('Disconnected from Web Panel workspace')}`
    ],
  });
  console.log('');
}
