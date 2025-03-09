import { compare } from 'bcryptjs';
import { prisma } from '../../lib/prisma';
import { authenticateUser } from './auth';

// Mock dependencies
jest.mock('bcryptjs', () => ({
  compare: jest.fn(),
}));

jest.mock('../../lib/prisma', () => ({
  prisma: {
    user: {
      findUnique: jest.fn(),
    },
  },
}));

describe('authenticateUser', () => {
  const mockUser = {
    id: '1',
    email: 'test@example.com',
    name: 'Test User',
    password: 'hashedPassword123',
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should successfully authenticate with valid credentials', async () => {
    // Mock successful password comparison
    (compare as jest.Mock).mockResolvedValue(true);
    // Mock finding the user
    (prisma.user.findUnique as jest.Mock).mockResolvedValue(mockUser);

    const result = await authenticateUser({
      email: 'test@example.com',
      password: 'correctPassword',
    });

    expect(prisma.user.findUnique).toHaveBeenCalledWith({
      where: { email: 'test@example.com' },
    });
    expect(compare).toHaveBeenCalledWith('correctPassword', mockUser.password);
    expect(result).toEqual({
      id: mockUser.id,
      email: mockUser.email,
      name: mockUser.name,
    });
  });

  it('should return null for invalid password', async () => {
    (compare as jest.Mock).mockResolvedValue(false);
    (prisma.user.findUnique as jest.Mock).mockResolvedValue(mockUser);

    const result = await authenticateUser({
      email: 'test@example.com',
      password: 'wrongPassword',
    });

    expect(prisma.user.findUnique).toHaveBeenCalledWith({
      where: { email: 'test@example.com' },
    });
    expect(compare).toHaveBeenCalledWith('wrongPassword', mockUser.password);
    expect(result).toBeNull();
  });

  it('should return null for non-existent user', async () => {
    (prisma.user.findUnique as jest.Mock).mockResolvedValue(null);

    const result = await authenticateUser({
      email: 'nonexistent@example.com',
      password: 'password123',
    });

    expect(prisma.user.findUnique).toHaveBeenCalledWith({
      where: { email: 'nonexistent@example.com' },
    });
    expect(compare).not.toHaveBeenCalled();
    expect(result).toBeNull();
  });

  it('should return null for missing email', async () => {
    const result = await authenticateUser({
      email: '',
      password: 'password123',
    });

    expect(prisma.user.findUnique).not.toHaveBeenCalled();
    expect(compare).not.toHaveBeenCalled();
    expect(result).toBeNull();
  });

  it('should return null for missing password', async () => {
    const result = await authenticateUser({
      email: 'test@example.com',
      password: '',
    });

    expect(prisma.user.findUnique).not.toHaveBeenCalled();
    expect(compare).not.toHaveBeenCalled();
    expect(result).toBeNull();
  });

  it('should return null when user exists but has no password', async () => {
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({
      ...mockUser,
      password: null,
    });

    const result = await authenticateUser({
      email: 'test@example.com',
      password: 'password123',
    });

    expect(prisma.user.findUnique).toHaveBeenCalledWith({
      where: { email: 'test@example.com' },
    });
    expect(compare).not.toHaveBeenCalled();
    expect(result).toBeNull();
  });
}); 