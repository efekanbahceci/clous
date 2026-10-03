import fs from 'node:fs';
import path from 'node:path';
import { getProjectConfigDir, getProjectConfigPath } from './paths.js';

export interface ProjectConfig {
  projectId: string;
  projectName?: string;
  orgId?: string;
  schemaPath?: string;
  outDir?: string;
  linkedAt?: string;
  permissions?: {
    trafficWatcher: boolean;
    envScanner: boolean;
    dbIntrospection: boolean;
  };
  database?: {
    driver: 'auto' | 'postgresql' | 'mongodb' | 'mysql';
    envKey: string;
  };
}

export class ProjectConfigManager {
  /**
   * Loads `.clous/project.json` if it exists.
   */
  static load(cwd: string = process.cwd()): ProjectConfig | null {
    const configPath = getProjectConfigPath(cwd);
    if (!fs.existsSync(configPath)) {
      return null;
    }

    try {
      const raw = fs.readFileSync(configPath, 'utf8');
      return JSON.parse(raw) as ProjectConfig;
    } catch {
      return null;
    }
  }

  /**
   * Saves project configuration to `.clous/project.json`.
   */
  static save(config: ProjectConfig, cwd: string = process.cwd()): void {
    const dir = getProjectConfigDir(cwd);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    const configPath = getProjectConfigPath(cwd);
    const payload: ProjectConfig = {
      ...config,
      linkedAt: config.linkedAt || new Date().toISOString(),
    };

    fs.writeFileSync(configPath, JSON.stringify(payload, null, 2), 'utf8');

    // Ensure .gitignore ignores sensitive or ephemeral project files if needed
    const gitignorePath = path.join(cwd, '.gitignore');
    if (fs.existsSync(gitignorePath)) {
      try {
        const gitignoreContent = fs.readFileSync(gitignorePath, 'utf8');
        if (!gitignoreContent.includes('.clous/credentials.json')) {
          fs.appendFileSync(
            gitignorePath,
            '\n# Clous CLI local auth\n.clous/credentials.json\n'
          );
        }
      } catch {
        // Ignore gitignore write error
      }
    }
  }

  /**
   * Removes project linkage.
   */
  static unlink(cwd: string = process.cwd()): boolean {
    const configPath = getProjectConfigPath(cwd);
    if (fs.existsSync(configPath)) {
      try {
        fs.unlinkSync(configPath);
        return true;
      } catch {
        return false;
      }
    }
    return false;
  }
}
