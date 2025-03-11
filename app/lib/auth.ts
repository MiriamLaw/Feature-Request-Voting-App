import { compare } from 'bcryptjs';
import { prisma } from '@/lib/prisma';

export interface AuthenticateParams {
  email: string;
  password: string;
}

export interface AuthenticatedUser {
  id: string;
  email: string;
  name: string | null;
}

export async function authenticateUser({ email, password }: AuthenticateParams): Promise<AuthenticatedUser | null> {
  if (!email || !password) {
    return null;
  }

  const user = await prisma.user.findUnique({
    where: { email }
  });

  if (!user?.password) {
    return null;
  }

  const isPasswordValid = await compare(password, user.password);

  if (!isPasswordValid) {
    return null;
  }

  return {
    id: user.id,
    email: user.email,
    name: user.name,
  };
} 