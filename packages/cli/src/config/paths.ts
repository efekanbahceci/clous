import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

/**
 * Returns the OS-specific global configuration directory for Clous.
 * - Windows: %APPDATA%/clous
 * - macOS/Linux: ~/.config/clous (or $XDG_CONFIG_HOME/clous)
 */
export function getGlobalConfigDir(): string {
  if (process.env.CLOUS_CONFIG_DIR) {
    return process.env.CLOUS_CONFIG_DIR;
  }

  if (process.platform === 'win32') {
    const appData = process.env.APPDATA || path.join(os.homedir(), 'AppData', 'Roaming');
    return path.join(appData, 'clous');
  }

  const xdgConfig = process.env.XDG_CONFIG_HOME;
  if (xdgConfig) {
    return path.join(xdgConfig, 'clous');
  }

  return path.join(os.homedir(), '.config', 'clous');
}

/**
 * Path to global credentials file where CLI auth tokens are stored.
 */
export function getCredentialsPath(): string {
  if (process.env.CLOUS_CREDENTIALS_FILE) {
    return process.env.CLOUS_CREDENTIALS_FILE;
  }
  return path.join(getGlobalConfigDir(), 'credentials.json');
}

/**
 * Path to project-level `.clous` configuration directory.
 */
export function getProjectConfigDir(cwd: string = process.cwd()): string {
  return path.join(cwd, '.clous');
}

/**
 * Path to project-level `project.json` configuration file.
 */
export function getProjectConfigPath(cwd: string = process.cwd()): string {
  return path.join(getProjectConfigDir(cwd), 'project.json');
}

/**
 * Finds the default schema file path in the current working directory.
 */
export function resolveSchemaPath(cwd: string = process.cwd(), explicitPath?: string): string {
  if (explicitPath) {
    const resolved = path.isAbsolute(explicitPath) ? explicitPath : path.resolve(cwd, explicitPath);
    if (!fs.existsSync(resolved)) {
      throw new Error(`Schema file not found at: ${resolved}`);
    }
    return resolved;
  }

  const candidates = [
    path.join(cwd, 'schema.ts'),
    path.join(cwd, 'src', 'schema.ts'),
    path.join(cwd, 'schema.js'),
    path.join(cwd, 'src', 'schema.js'),
    path.join(cwd, 'clous.schema.ts'),
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }

  return path.join(cwd, 'schema.ts');
}
