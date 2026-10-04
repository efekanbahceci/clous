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
  const cwd = options.cwd || process.cwd();
  const configPath = getProjectConfigPath(cwd);

  let localConfig: any = null;
  if (fs.existsSync(configPath)) {
    try {
      localConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    } catch (e) {}
  }

  const targetId = options.projectId || localConfig?.projectId;

  if (!targetId && !localConfig) {
    logger.warn('No active project link found in this directory.');
    return;
  }

  // 1. Delete the local .clous/project.json file
  if (localConfig) {
    try {
      fs.unlinkSync(configPath);
      const clousDir = path.dirname(configPath);
      if (fs.readdirSync(clousDir).length === 0) {
        fs.rmdirSync(clousDir);
      }
    } catch (error) {
      logger.error(`Failed to remove local link file: ${error}`);
    }
  }

  // 2. Notify the backend to remove the link
  if (token && targetId) {
    try {
      const endpoint = `${apiBase}/api/projects/${targetId}/unlink`;
      await fetch(endpoint, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      });
    } catch (e) {
      // ignore network errors on unlink
    }
  }

  console.log('');
  ui.box({
    title: 'Project Unlinked',
    borderColor: ansi.yellow,
    minWidth: 60,
    lines: [
      `Target ID     ${ansi.bold(targetId || 'unknown')}`,
      `Status        ${ansi.red('Disconnected from Web Panel workspace')}`
    ],
  });
  console.log('');
}
