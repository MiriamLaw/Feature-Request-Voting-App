const ADMIN_EMAIL = 'miriam.p.law@gmail.com';

export function isAdmin(email: string | null | undefined) {
  return email === ADMIN_EMAIL;
} 