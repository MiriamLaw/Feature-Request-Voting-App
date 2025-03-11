import { compare } from 'bcryptjs';
import { prisma } from './prisma';

const ADMIN_EMAIL = 'miriam.p.law@gmail.com';

export function isAdmin(email: string | null | undefined) {
  
  return email === ADMIN_EMAIL;
}

interface AuthenticateParams {
  email: string;
  password: string;
}

export async function authenticateUser({ email, password }: AuthenticateParams) {
  const user = await prisma.user.findUnique({
    where: { email },
  });

  if (!user || !user.password) {
    return null;
  }

  const isValid = await compare(password, user.password);

  if (!isValid) {
    return null;
  }

  return {
    id: user.id,
    email: user.email,
    name: user.name,
  };
} 