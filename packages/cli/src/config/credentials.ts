import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { getCredentialsPath, getGlobalConfigDir } from './paths.js';

export interface ClousProfile {
  id?: string;
  email?: string;
  name?: string;
  role?: string;
}

export interface Credentials {
  token?: string;
  apiUrl?: string;
  profile?: ClousProfile;
  updatedAt?: string;
}

const DEFAULT_API_URL = process.env.CLOUS_API_URL || 'https://clous.dev';

function getFallbackGlobalCredentialsPath(): string {
  return path.join(os.homedir(), '.clous', 'credentials.json');
}

export class CredentialsManager {
  /**
   * Loads user-global credentials, prioritizing environment variables over stored file.
   * Credentials are NEVER loaded from project-local `.clous/credentials.json` so that
   * cloning a repository on another computer never reports a false logged-in state,
   * while switching between projects on the same computer preserves the global login.
   */
  static load(): Credentials {
    let fileCreds: Credentials = {};

    const credsPath = getCredentialsPath();
    const fallbackPath = getFallbackGlobalCredentialsPath();

    if (fs.existsSync(credsPath)) {
      try {
        const raw = fs.readFileSync(credsPath, 'utf8');
        fileCreds = JSON.parse(raw);
      } catch {
        fileCreds = {};
      }
    } else if (fs.existsSync(fallbackPath)) {
      try {
        const raw = fs.readFileSync(fallbackPath, 'utf8');
        fileCreds = JSON.parse(raw);
      } catch {
        fileCreds = {};
      }
    }

    // Invalidate legacy mock/dev_user sessions that were previously persisted by mistake
    if (
      fileCreds.profile?.id === 'dev_user' ||
      fileCreds.profile?.email === 'developer@clous.local'
    ) {
      this.clear();
      fileCreds = {};
    }

    const envToken = process.env.CLOUS_ACCESS_TOKEN;
    const envApiUrl = process.env.CLOUS_API_URL;
    let resolvedApiUrl = envApiUrl || fileCreds.apiUrl || DEFAULT_API_URL;
    if (resolvedApiUrl === 'https://api.clous.dev') {
      resolvedApiUrl = DEFAULT_API_URL;
    }

    return {
      token: envToken || fileCreds.token,
      apiUrl: resolvedApiUrl,
      profile: fileCreds.profile,
      updatedAt: fileCreds.updatedAt,
    };
  }

  /**
   * Saves credentials to user-global disk with restricted permissions (0o600).
   */
  static save(creds: Credentials): void {
    const payload = {
      token: creds.token,
      apiUrl: creds.apiUrl || DEFAULT_API_URL,
      profile: creds.profile,
      updatedAt: new Date().toISOString(),
    };

    try {
      const configDir = getGlobalConfigDir();
      if (!fs.existsSync(configDir)) {
        fs.mkdirSync(configDir, { recursive: true, mode: 0o700 });
      }

      const credsPath = getCredentialsPath();
      fs.writeFileSync(credsPath, JSON.stringify(payload, null, 2), {
        encoding: 'utf8',
        mode: 0o600,
      });
    } catch {
      // Fallback to ~/.clous/credentials.json (still user-global, never inside project cwd)
      const fallbackDir = path.dirname(getFallbackGlobalCredentialsPath());
      if (!fs.existsSync(fallbackDir)) {
        fs.mkdirSync(fallbackDir, { recursive: true, mode: 0o700 });
      }
      fs.writeFileSync(getFallbackGlobalCredentialsPath(), JSON.stringify(payload, null, 2), {
        encoding: 'utf8',
        mode: 0o600,
      });
    }
  }

  /**
   * Removes credentials file from disk.
   */
  static clear(): boolean {
    let cleared = false;

    const candidates = [
      getCredentialsPath(),
      getFallbackGlobalCredentialsPath(),
      path.join(process.cwd(), '.clous', 'credentials.json'),
    ];

    for (const filePath of candidates) {
      if (fs.existsSync(filePath)) {
        try {
          fs.unlinkSync(filePath);
          cleared = true;
        } catch {
          // ignore
        }
      }
    }

    return cleared;
  }

  /**
   * Returns current active access token, if any.
   */
  static getToken(): string | undefined {
    return this.load().token;
  }

  /**
   * Returns current active API URL.
   */
  static getApiUrl(): string {
    const loaded = this.load();
    return process.env.CLOUS_API_URL || loaded.apiUrl || DEFAULT_API_URL;
  }
}
