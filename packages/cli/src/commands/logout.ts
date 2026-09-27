import { AuthService } from '../auth/auth-service.js';

export async function logoutCommand(): Promise<void> {
  await AuthService.logout();
}
