import crypto from 'node:crypto';
import { CredentialsManager, type ClousProfile } from '../config/credentials.js';
import { ApiClient } from './client.js';
import { ansi } from '../utils/ansi.js';
import { ui } from '../utils/ui.js';
import { openBrowser } from '../utils/browser.js';

export interface LoginOptions {
  token?: string;
  apiUrl?: string;
  port?: number;
  force?: boolean;
}

interface CliSessionPollResponse {
  status: 'pending' | 'authorized' | 'expired' | 'invalid' | 'error';
  token?: string;
  profile?: ClousProfile;
  error?: string;
}

export class AuthService {
  /**
   * Authenticates the CLI either with a provided token or via https://clous.dev browser flow.
   */
  static async login(options: LoginOptions = {}): Promise<void> {
    const apiUrl = (options.apiUrl || CredentialsManager.getApiUrl()).replace(/\/+$/, '');
    const client = new ApiClient({ baseUrl: apiUrl });

    // 1. Direct token login (CI/CD or headless)
    if (options.token) {
      const verification = await client.verifyToken(options.token);
      if (!verification.valid) {
        throw new Error(verification.error || 'Token verification failed.');
      }

      CredentialsManager.save({
        token: options.token,
        apiUrl,
        profile: verification.profile,
      });

      console.log('');
      ui.box({
        title: 'Authentication Successful',
        borderColor: ansi.green,
        lines: [
          `User Account  ${ansi.bold(verification.profile?.email || verification.profile?.id || 'Authenticated User')}`,
          `API Endpoint  ${ansi.dim(apiUrl)}`,
          `Status        ${ansi.green('Active (Session saved safely)')}`,
        ],
      });
      console.log('');
      return;
    }

    // 2. Interactive Cloud Session Flow on https://clous.dev
    const sessionId = crypto.randomBytes(16).toString('hex');
    const loginUrl = `${apiUrl}/cli/auth?session_id=${sessionId}`;

    console.log('');
    ui.box({
      title: 'Clous Authentication',
      borderColor: ansi.cyan,
      lines: [
        'Opening your browser to authenticate with Clous...',
        '',
        'If the browser does not open automatically, visit:',
        ansi.cyan(loginUrl),
      ],
    });
    console.log('');

    // Open https://clous.dev/cli/auth?session_id=... in the user's browser
    openBrowser(loginUrl);

    const slowMo = await ui.startSlowMotionBanner('0.1.0', {
      statusMessage: ansi.dim(`Waiting for authorization on ${apiUrl}... (Press Ctrl+C to cancel)`),
    });

    let sessionResult: { token: string; profile?: ClousProfile };
    try {
      sessionResult = await this.pollCloudSession(apiUrl, sessionId);
    } finally {
      slowMo.stop();
    }

    // Verify token against the API
    const verification = await client.verifyToken(sessionResult.token);
    if (!verification.valid) {
      throw new Error(verification.error || 'Received invalid token from authentication provider.');
    }

    const finalProfile = verification.profile || sessionResult.profile;

    CredentialsManager.save({
      token: sessionResult.token,
      apiUrl,
      profile: finalProfile,
    });

    console.log('');
    ui.box({
      title: 'Authentication Successful',
      borderColor: ansi.green,
      lines: [
        `User Account  ${ansi.bold(finalProfile?.email || finalProfile?.id || 'Authenticated User')}`,
        `API Endpoint  ${ansi.dim(apiUrl)}`,
        `Status        ${ansi.green('Active (Session saved safely)')}`,
      ],
    });
    console.log('');
  }

  /**
   * Logs out the CLI by removing local credentials.
   */
  static async logout(): Promise<void> {
    CredentialsManager.clear();
  }

  /**
   * Returns current active profile and login status.
   * Automatically clears stale/invalid tokens so the user is never stuck in a ghost session.
   */
  static async whoami(): Promise<{ loggedIn: boolean; profile?: ClousProfile; apiUrl: string }> {
    const creds = CredentialsManager.load();
    const apiUrl = creds.apiUrl || CredentialsManager.getApiUrl();

    if (!creds.token) {
      return { loggedIn: false, apiUrl };
    }

    // Verify token is still valid against the server
    const client = new ApiClient({ baseUrl: apiUrl, token: creds.token });
    const verification = await client.verifyToken(creds.token);

    if (!verification.valid) {
      CredentialsManager.clear();
      return { loggedIn: false, apiUrl };
    }

    // Keep cached profile up to date if the server returned fresh user info
    if (
      verification.profile &&
      (!creds.profile ||
        creds.profile.email !== verification.profile.email ||
        creds.profile.id !== verification.profile.id)
    ) {
      CredentialsManager.save({
        token: creds.token,
        apiUrl,
        profile: verification.profile,
      });
    }

    return {
      loggedIn: true,
      profile: verification.profile || creds.profile,
      apiUrl,
    };
  }

  /**
   * Polls `https://clous.dev/api/cli/session?session_id=...` until the user clicks "Authorize" on clous.dev.
   */
  private static async pollCloudSession(
    apiUrl: string,
    sessionId: string
  ): Promise<{ token: string; profile?: ClousProfile }> {
    const pollIntervalMs = 1500;
    const timeoutMs = 5 * 60 * 1000; // 5 minutes
    const deadline = Date.now() + timeoutMs;
    const endpoint = `${apiUrl}/api/cli/session?session_id=${encodeURIComponent(sessionId)}`;

    while (Date.now() < deadline) {
      try {
        const res = await fetch(endpoint, {
          method: 'GET',
          headers: {
            Accept: 'application/json',
            'User-Agent': '@clous/cli',
          },
        });

        if (res.status === 410) {
          throw new Error('Authentication session expired. Please run "clous login" again.');
        }

        if (res.ok) {
          const data = (await res.json()) as CliSessionPollResponse;
          if (data.status === 'authorized' && data.token) {
            return {
              token: data.token,
              profile: data.profile,
            };
          }
          if (data.status === 'expired') {
            throw new Error(data.error || 'Authentication session expired.');
          }
        }
      } catch (err: any) {
        if (err.message?.includes('expired')) {
          throw err;
        }
        // Ignore transient network errors while polling
      }

      await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
    }

    throw new Error('Authentication timed out after 5 minutes.');
  }
}
