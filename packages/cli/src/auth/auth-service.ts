import http from 'node:http';
import crypto from 'node:crypto';
import { CredentialsManager, type ClousProfile } from '../config/credentials.js';
import { ApiClient } from './client.js';
import { logger } from '../utils/logger.js';
import { ansi } from '../utils/ansi.js';
import { ui } from '../utils/ui.js';
import { openBrowser } from '../utils/browser.js';

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

      console.log('');
      ui.box({
        title: 'Authentication Successful',
        borderColor: ansi.green,
        lines: [
          `User Account  ${ansi.bold(verification.profile?.email || 'developer@clous.local')}`,
          `API Endpoint  ${ansi.dim(apiUrl)}`,
          `Status        ${ansi.green('Active (Session saved safely)')}`,
        ],
      });
      console.log('');
      return;
    }

    // 2. Interactive Browser Flow with Ephemeral Local Server
    const port = options.port || 45678;
    const sessionId = crypto.randomBytes(16).toString('hex');
    const callbackUrl = `http://localhost:${port}/callback`;
    const loginUrl = `${apiUrl}/cli/auth?session_id=${sessionId}&callback=${encodeURIComponent(callbackUrl)}`;

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

    // Automatically open browser for seamless authentication
    openBrowser(loginUrl);

    const slowMo = await ui.startSlowMotionBanner('0.1.0', {
      statusMessage: ansi.dim(`Waiting for browser authorization on port ${port}... (Press Ctrl+C to cancel)`),
    });

    let token: string;
    try {
      token = await this.startCallbackServer(port, sessionId);
    } finally {
      slowMo.stop();
    }

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

    console.log('');
    ui.box({
      title: 'Authentication Successful',
      borderColor: ansi.green,
      lines: [
        `User Account  ${ansi.bold(verification.profile?.email || 'developer@clous.local')}`,
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
            <html lang="tr">
              <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>Clous CLI Authentication</title>
                <style>
                  * { box-sizing: border-box; }
                  body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    min-height: 100vh;
                    margin: 0;
                    background-color: #111014;
                    color: #fafafa;
                    position: relative;
                    overflow: hidden;
                  }
                  .glow {
                    position: absolute;
                    width: 500px;
                    height: 350px;
                    background: radial-gradient(circle, rgba(255, 87, 8, 0.15) 0%, rgba(17, 16, 20, 0) 70%);
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    pointer-events: none;
                  }
                  .card {
                    position: relative;
                    background: rgba(24, 24, 27, 0.7);
                    backdrop-filter: blur(16px);
                    -webkit-backdrop-filter: blur(16px);
                    border: 1px solid rgba(39, 39, 42, 0.8);
                    border-radius: 16px;
                    padding: 40px 32px;
                    max-width: 440px;
                    width: 90%;
                    text-align: center;
                    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
                  }
                  .badge {
                    display: inline-flex;
                    align-items: center;
                    gap: 6px;
                    padding: 4px 12px;
                    border-radius: 9999px;
                    background: rgba(255, 87, 8, 0.1);
                    border: 1px solid rgba(255, 87, 8, 0.2);
                    color: #FF5708;
                    font-size: 12px;
                    font-weight: 500;
                    margin-bottom: 20px;
                  }
                  .icon {
                    width: 64px;
                    height: 64px;
                    border-radius: 50%;
                    background: rgba(255, 87, 8, 0.15);
                    border: 1px solid rgba(255, 87, 8, 0.4);
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    margin: 0 auto 20px auto;
                    box-shadow: 0 0 30px rgba(255, 87, 8, 0.25);
                  }
                  .icon svg {
                    width: 32px;
                    height: 32px;
                    stroke: #FF5708;
                  }
                  h1 {
                    font-size: 22px;
                    font-weight: 600;
                    margin: 0 0 10px 0;
                    color: #ffffff;
                    letter-spacing: -0.02em;
                  }
                  p {
                    color: #a1a1aa;
                    font-size: 14px;
                    line-height: 1.6;
                    margin: 0 0 16px 0;
                  }
                  .hint {
                    color: #71717a;
                    font-size: 12px;
                    margin: 0;
                  }
                </style>
              </head>
              <body>
                <div class="glow"></div>
                <div class="card">
                  <div class="badge">
                    <span>Clous CLI</span>
                  </div>
                  <div class="icon">
                    <svg viewBox="0 0 24 24" fill="none" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
                      <polyline points="22 4 12 14.01 9 11.01" />
                    </svg>
                  </div>
                  <h1>Yetkilendirme Başarılı</h1>
                  <p>Clous CLI başarıyla yetkilendirildi. Bu sekmeyi kapatıp terminalinize geri dönebilirsiniz.</p>
                  <p class="hint">Bu pencere otomatik olarak kapatılabilir.</p>
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
