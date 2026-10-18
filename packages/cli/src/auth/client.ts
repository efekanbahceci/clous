import { CredentialsManager } from '../config/credentials.js';

export interface VerifyTokenResponse {
  valid: boolean;
  profile?: {
    id?: string;
    email?: string;
    name?: string;
    role?: string;
  };
  error?: string;
}

export class ApiClient {
  private readonly baseUrl: string;
  private readonly token?: string;

  constructor(options: { baseUrl?: string; token?: string } = {}) {
    this.baseUrl = options.baseUrl || CredentialsManager.getApiUrl();
    this.token = options.token || CredentialsManager.getToken();
  }

  async request<T = any>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = new URL(endpoint, this.baseUrl).toString();
    const headers = new Headers(options.headers || {});

    headers.set('User-Agent', '@clous/cli');
    headers.set('Accept', 'application/json');

    if (this.token && !headers.has('Authorization')) {
      headers.set('Authorization', `Bearer ${this.token}`);
    }

    const res = await fetch(url, {
      ...options,
      headers,
    });

    if (!res.ok) {
      const errorBody = await res.text().catch(() => '');
      let errorMessage = `HTTP ${res.status} ${res.statusText}`;
      try {
        const parsed = JSON.parse(errorBody);
        errorMessage = parsed.message || parsed.error || errorMessage;
      } catch {
        if (errorBody) {
          errorMessage = `${errorMessage}: ${errorBody}`;
        }
      }
      const err = new Error(errorMessage);
      (err as any).status = res.status;
      throw err;
    }

    const contentType = res.headers.get('content-type') || '';
    if (contentType.includes('application/json')) {
      return (await res.json()) as T;
    }

    return (await res.text()) as unknown as T;
  }

  /**
   * Verifies an access token against the control plane API.
   */
  async verifyToken(token: string): Promise<VerifyTokenResponse> {
    try {
      const data = await this.request<VerifyTokenResponse>('/api/cli/verify', {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });

      if (
        !data?.valid ||
        data.profile?.id === 'dev_user' ||
        data.profile?.email === 'developer@clous.local'
      ) {
        return {
          valid: false,
          error: data?.error || 'Invalid or expired authentication token.',
        };
      }

      return data;
    } catch (err: any) {
      if (err.status === 401 || err.status === 403) {
        return {
          valid: false,
          error: err.message || 'Unauthorized token.',
        };
      }

      // If the remote server is temporarily unreachable, only trust an already-verified real profile on disk
      const saved = CredentialsManager.load();
      if (
        saved.token === token &&
        saved.profile?.id &&
        saved.profile.id !== 'dev_user' &&
        saved.profile?.email &&
        saved.profile.email !== 'developer@clous.local'
      ) {
        return {
          valid: true,
          profile: saved.profile,
        };
      }

      return {
        valid: false,
        error: `Could not verify token with ${this.baseUrl}: ${err.message || 'Network error'}`,
      };
    }
  }
}
