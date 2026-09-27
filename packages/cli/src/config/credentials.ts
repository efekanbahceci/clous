import fs from 'node:fs';
import path from 'node:path';
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

const DEFAULT_API_URL = 'https://api.clous.dev';

export class CredentialsManager {
  /**
   * Loads credentials, prioritizing environment variables over stored file.
   */
  static load(): Credentials {
    let fileCreds: Credentials = {};

    const credsPath = getCredentialsPath();
    if (fs.existsSync(credsPath)) {
      try {
        const raw = fs.readFileSync(credsPath, 'utf8');
        fileCreds = JSON.parse(raw);
      } catch {
        fileCreds = {};
      }
    }

    const localPath = path.join(process.cwd(), '.clous', 'credentials.json');
    if (!fileCreds.token && fs.existsSync(localPath)) {
      try {
        const raw = fs.readFileSync(localPath, 'utf8');
        fileCreds = JSON.parse(raw);
      } catch {
        // Ignore corrupted local file
      }
    }

    const envToken = process.env.CLOUS_ACCESS_TOKEN;
    const envApiUrl = process.env.CLOUS_API_URL;

    return {
      token: envToken || fileCreds.token,
      apiUrl: envApiUrl || fileCreds.apiUrl || DEFAULT_API_URL,
      profile: fileCreds.profile,
      updatedAt: fileCreds.updatedAt,
    };
  }

  /**
   * Saves credentials to disk with restricted permissions (0o600).
   * If global directory is not writable (e.g. sandbox or restricted env), falls back to local .clous/credentials.json.
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
      // Fallback to local .clous/credentials.json if global OS directory is unwritable
      const localDir = path.join(process.cwd(), '.clous');
      if (!fs.existsSync(localDir)) {
        fs.mkdirSync(localDir, { recursive: true });
      }
      const localCredsPath = path.join(localDir, 'credentials.json');
      fs.writeFileSync(localCredsPath, JSON.stringify(payload, null, 2), {
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

    const credsPath = getCredentialsPath();
    if (fs.existsSync(credsPath)) {
      try {
        fs.unlinkSync(credsPath);
        cleared = true;
      } catch {
        // ignore
      }
    }

    const localCredsPath = path.join(process.cwd(), '.clous', 'credentials.json');
    if (fs.existsSync(localCredsPath)) {
      try {
        fs.unlinkSync(localCredsPath);
        cleared = true;
      } catch {
        // ignore
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
    return this.load().apiUrl || DEFAULT_API_URL;
  }
}
