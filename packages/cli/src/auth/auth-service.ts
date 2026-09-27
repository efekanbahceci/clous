import http from 'node:http';
import crypto from 'node:crypto';
import { CredentialsManager, type ClousProfile } from '../config/credentials.js';
import { ApiClient } from './client.js';
import { logger } from '../utils/logger.js';
import { ansi } from '../utils/ansi.js';

export interface LoginOptions {
  token?: string;
  apiUrl?: string;
  port?: number;
}

export class AuthService {
  /**
   * Authenticates the CLI either with a provided token or via browser OAuth flow.
   */
  static async login(options: LoginOptions = {}): Promise<void> {
    const apiUrl = options.apiUrl || CredentialsManager.getApiUrl();
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

      logger.success('Successfully authenticated with provided token.');
      if (verification.profile?.email) {
        logger.info(`Logged in as: ${verification.profile.email}`);
      }
      return;
    }

    // 2. Interactive Browser Flow with Ephemeral Local Server
    const port = options.port || 45678;
    const sessionId = crypto.randomBytes(16).toString('hex');
    const callbackUrl = `http://localhost:${port}/callback`;
    const loginUrl = `${apiUrl}/cli/auth?session_id=${sessionId}&callback=${encodeURIComponent(callbackUrl)}`;

    logger.info('Starting local authentication listener...');
    logger.plain('');
    logger.plain(`Please open the following URL in your browser to authenticate:`);
    logger.plain(ansi.cyan(loginUrl));
    logger.plain('');
    logger.plain(ansi.dim(`Waiting for browser authorization on port ${port}... (Press Ctrl+C to cancel)`));

    const token = await this.startCallbackServer(port, sessionId);

    // Verify token
    const verification = await client.verifyToken(token);
    if (!verification.valid) {
      throw new Error(verification.error || 'Received invalid token from authentication provider.');
    }

    CredentialsManager.save({
      token,
      apiUrl,
      profile: verification.profile,
    });

    logger.success('Authentication successful!');
    if (verification.profile?.email) {
      logger.info(`Logged in as: ${verification.profile.email}`);
    }
  }

  /**
   * Logs out the CLI by removing local credentials.
   */
  static async logout(): Promise<void> {
    const cleared = CredentialsManager.clear();
    if (cleared) {
      logger.success('Logged out successfully. Stored credentials removed.');
    } else {
      logger.info('No active session found. Already logged out.');
    }
  }

  /**
   * Returns current active profile and login status.
   */
  static async whoami(): Promise<{ loggedIn: boolean; profile?: ClousProfile; apiUrl: string }> {
    const creds = CredentialsManager.load();
    const apiUrl = creds.apiUrl || CredentialsManager.getApiUrl();

    if (!creds.token) {
      return { loggedIn: false, apiUrl };
    }

    // Verify token is still valid
    const client = new ApiClient({ baseUrl: apiUrl, token: creds.token });
    const verification = await client.verifyToken(creds.token);

    if (!verification.valid) {
      return { loggedIn: false, apiUrl };
    }

    return {
      loggedIn: true,
      profile: verification.profile || creds.profile,
      apiUrl,
    };
  }

  private static startCallbackServer(port: number, expectedSessionId: string): Promise<string> {
    return new Promise((resolve, reject) => {
      let resolved = false;

      const server = http.createServer((req, res) => {
        const reqUrl = new URL(req.url || '/', `http://localhost:${port}`);

        if (reqUrl.pathname === '/callback') {
          const token = reqUrl.searchParams.get('token');
          const sessionId = reqUrl.searchParams.get('session_id');

          if (sessionId && sessionId !== expectedSessionId) {
            res.writeHead(400, { 'Content-Type': 'text/plain' });
            res.end('Invalid session verification. Please retry login.');
            return;
          }

          if (!token) {
            res.writeHead(400, { 'Content-Type': 'text/plain' });
            res.end('Missing token in callback response.');
            return;
          }

          resolved = true;
          res.writeHead(200, { 'Content-Type': 'text/html' });
          res.end(`
            <!DOCTYPE html>
            <html>
              <head>
                <meta charset="utf-8">
                <title>Clous CLI Authentication</title>
                <style>
                  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #09090b; color: #fafafa; }
                  .card { background: #18181b; border: 1px solid #27272a; border-radius: 8px; padding: 32px; max-width: 440px; text-align: center; }
                  h1 { font-size: 20px; margin-bottom: 8px; color: #10b981; }
                  p { color: #a1a1aa; font-size: 14px; line-height: 1.5; }
                </style>
              </head>
              <body>
                <div class="card">
                  <h1>Authentication Successful</h1>
                  <p>Your Clous CLI has been authorized. You can close this window and return to your terminal.</p>
                </div>
              </body>
            </html>
          `);

          server.close(() => {
            resolve(token);
          });
        } else {
          res.writeHead(404, { 'Content-Type': 'text/plain' });
          res.end('Not Found');
        }
      });

      server.on('error', (err) => {
        if (!resolved) {
          reject(new Error(`Failed to start local login listener on port ${port}: ${err.message}`));
        }
      });

      // 5-minute timeout for interactive login
      const timeout = setTimeout(() => {
        if (!resolved) {
          server.close();
          reject(new Error('Authentication timed out after 5 minutes.'));
        }
      }, 5 * 60 * 1000);

      server.listen(port, '127.0.0.1', () => {
        server.unref();
      });

      server.on('close', () => {
        clearTimeout(timeout);
      });
    });
  }
}
