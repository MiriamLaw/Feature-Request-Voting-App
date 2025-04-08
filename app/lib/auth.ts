import { compare } from 'bcryptjs';
import { prisma } from '@/lib/prisma';
import { getServerSession } from 'next-auth';
import { authOptions } from '@/app/api/auth/[...nextauth]/route';

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
    email: user.email || '',
    name: user.name,
  };
}

// Server-side function - do not import in client components
export async function isAdmin(): Promise<boolean> {
  const session = await getServerSession(authOptions);
  return session?.user?.role === 'ADMIN';
}

// Client-side function - safe to import in client components
export function useIsAdmin(): boolean {
  // This is a placeholder - in a real implementation, you would use a React hook
  // to get the user's role from the session
  return false;
} 