import { compare } from 'bcryptjs';
import { authOptions } from './route';
import { prisma } from '@/lib/prisma';
import { JWT } from 'next-auth/jwt';
import type { AdapterUser } from 'next-auth/adapters';
import type { Session } from 'next-auth';
import type { CredentialsConfig } from 'next-auth/providers/credentials';
import type { User } from 'next-auth';
import type { AuthenticatedUser } from '../../../lib/auth';

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
const mockAuthenticateUser = jest.fn();
jest.mock('../../../lib/auth', () => ({
  authenticateUser: mockAuthenticateUser,
}));

describe('NextAuth Configuration', () => {
  const mockUser: AuthenticatedUser = {
    id: '1',
    email: 'test@example.com',
    name: 'Test User',
  };

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

  describe('CredentialsProvider', () => {
    describe('authorize function', () => {
      const credentialsProvider = authOptions.providers[0] as CredentialsConfig;

      it('should return null when credentials are missing', async () => {
        const result = await credentialsProvider.authorize!({} as any, {} as any);
        expect(result).toBeNull();
      });

      it('should return null when email is missing', async () => {
        const result = await credentialsProvider.authorize!({
          password: 'password123'
        } as any, {} as any);
        expect(result).toBeNull();
      });

      it('should return null when password is missing', async () => {
        const result = await credentialsProvider.authorize!({
          email: 'test@example.com'
        } as any, {} as any);
        expect(result).toBeNull();
      });

      it('should return null when authentication fails', async () => {
        mockAuthenticateUser.mockResolvedValueOnce(null);

        const result = await credentialsProvider.authorize!({
          email: 'test@example.com',
          password: 'wrongpassword'
        } as any, {} as any);
        expect(result).toBeNull();
      });

      it('should return user object when authentication succeeds', async () => {
        const mockAuthenticatedUser = {
          id: '1',
          email: 'test@example.com',
          name: 'Test User',
        } as AuthenticatedUser;
        
        const credentials = {
          email: 'test@example.com',
          password: 'correctpassword'
        };

        // Set up the mock to return our mock user
        mockAuthenticateUser.mockResolvedValue(mockAuthenticatedUser);

        // Call the authorize function
        const result = await credentialsProvider.authorize!(credentials as any, {} as any);

        // Verify authenticateUser was called with the correct arguments
        expect(mockAuthenticateUser).toHaveBeenCalledWith({
          email: credentials.email,
          password: credentials.password,
        });

        // Verify the result matches our expected user object
        expect(result).toEqual({
          id: mockAuthenticatedUser.id,
          email: mockAuthenticatedUser.email,
          name: mockAuthenticatedUser.name,
        });
      });
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
          user: null as unknown as User | AdapterUser,
          account: null,
          profile: undefined,
          trigger: undefined,
          session: null,
          isNewUser: false,
        });

        expect(result).toEqual(mockToken);
      });

      it('should handle missing user gracefully', () => {
        const mockToken: JWT = {
          email: 'test@example.com',
          name: 'Test User',
        };

        const result = authOptions.callbacks!.jwt!({
          token: mockToken,
          user: null as unknown as User | AdapterUser,
          account: null,
          profile: undefined,
          trigger: undefined,
          session: null,
          isNewUser: false,
        });

        expect(result).toEqual(mockToken);
      });
    });
  });
}); 