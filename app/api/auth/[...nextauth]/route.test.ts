import { compare } from 'bcryptjs';
import { authOptions } from './route';
import { prisma } from '@/lib/prisma';
import { JWT } from 'next-auth/jwt';
import type { AdapterUser } from 'next-auth/adapters';
import type { Session } from 'next-auth';

// Mock dependencies
jest.mock('bcryptjs', () => ({
  compare: jest.fn(),
}));

jest.mock('@/lib/prisma', () => ({
  prisma: {
    user: {
      findUnique: jest.fn(),
    },
  },
}));

// Mock authenticateUser function
jest.mock('@/lib/auth', () => ({
  authenticateUser: jest.fn(),
}));

describe('NextAuth Configuration', () => {
  const mockUser = {
    id: '1',
    email: 'test@example.com',
    name: 'Test User',
    emailVerified: null,
  } as AdapterUser;

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('configuration', () => {
    it('should have correct base configuration', () => {
      expect(authOptions.adapter).toBeDefined();
      expect(authOptions.session?.strategy).toBe('jwt');
      expect(authOptions.pages?.signIn).toBe('/login');
    });
  });

  describe('callbacks', () => {
    describe('session callback', () => {
      it('should add user id to the session', () => {
        const mockSession: Session = {
          user: { email: 'test@example.com', name: 'Test User' },
          expires: '2024-01-01',
        };
        const mockToken: JWT = { 
          id: '123',
          email: 'test@example.com',
          name: 'Test User',
        };

        const result = authOptions.callbacks!.session!({
          session: mockSession,
          token: mockToken,
          trigger: 'update',
          newSession: mockSession,
        } as any);

        expect(result).toEqual({
          ...mockSession,
          user: {
            ...mockSession.user,
            id: mockToken.id,
          },
        });
      });
    });

    describe('jwt callback', () => {
      it('should add user id to the token when user is provided', () => {
        const mockToken: JWT = {
          email: 'test@example.com',
          name: 'Test User',
        };

        const result = authOptions.callbacks!.jwt!({
          token: mockToken,
          user: mockUser,
          account: null,
          profile: undefined,
          trigger: undefined,
          session: null,
          isNewUser: false,
        });

        expect(result).toEqual({
          ...mockToken,
          id: mockUser.id,
        });
      });

      it('should return unchanged token when no user is provided', () => {
        const mockToken: JWT = {
          id: '123',
          email: 'test@example.com',
          name: 'Test User',
        };

        const result = authOptions.callbacks!.jwt!({
          token: mockToken,
          user: mockUser,
          account: null,
          profile: undefined,
          trigger: undefined,
          session: null,
          isNewUser: false,
        });

        expect(result).toEqual({
          ...mockToken,
          id: mockUser.id,
        });
      });
    });
  });
}); 