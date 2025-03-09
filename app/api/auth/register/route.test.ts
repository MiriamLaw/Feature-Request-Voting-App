import { NextResponse } from 'next/server';
import { hash } from 'bcryptjs';
import { prisma } from '@/lib/prisma';
import { POST } from './route';

// Mock dependencies
jest.mock('next/server', () => ({
  NextResponse: {
    json: jest.fn(),
  },
}));

jest.mock('bcryptjs', () => ({
  hash: jest.fn(),
}));

jest.mock('@/lib/prisma', () => ({
  prisma: {
    user: {
      findUnique: jest.fn(),
      create: jest.fn(),
    },
  },
}));

describe('POST /api/auth/register', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  const mockRequest = (body: any) =>
    new Request('http://localhost:3000/api/auth/register', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

  it('should successfully register a new user', async () => {
    // Mock dependencies
    const hashedPassword = 'hashedPassword123';
    (hash as jest.Mock).mockResolvedValue(hashedPassword);
    (prisma.user.findUnique as jest.Mock).mockResolvedValue(null);
    (prisma.user.create as jest.Mock).mockResolvedValue({
      id: '1',
      name: 'Test User',
      email: 'test@example.com',
      password: hashedPassword,
    });
    (NextResponse.json as jest.Mock).mockImplementation((data, options) => ({
      ...data,
      status: options?.status,
    }));

    const requestBody = {
      name: 'Test User',
      email: 'test@example.com',
      password: 'password123',
    };

    const response = await POST(mockRequest(requestBody));

    expect(prisma.user.findUnique).toHaveBeenCalledWith({
      where: { email: requestBody.email },
    });
    expect(hash).toHaveBeenCalledWith(requestBody.password, 10);
    expect(prisma.user.create).toHaveBeenCalledWith({
      data: {
        name: requestBody.name,
        email: requestBody.email,
        password: hashedPassword,
      },
    });
    expect(response).toEqual({
      message: 'User created successfully',
      status: 201,
    });
  });

  it('should return error if user already exists', async () => {
    // Mock existing user
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({
      id: '1',
      email: 'existing@example.com',
    });
    (NextResponse.json as jest.Mock).mockImplementation((data, options) => ({
      ...data,
      status: options?.status,
    }));

    const requestBody = {
      name: 'Test User',
      email: 'existing@example.com',
      password: 'password123',
    };

    const response = await POST(mockRequest(requestBody));

    expect(prisma.user.findUnique).toHaveBeenCalledWith({
      where: { email: requestBody.email },
    });
    expect(prisma.user.create).not.toHaveBeenCalled();
    expect(response).toEqual({
      error: 'User already exists',
      status: 400,
    });
  });

  it('should handle database errors', async () => {
    // Mock database error
    (prisma.user.findUnique as jest.Mock).mockRejectedValue(new Error('Database error'));
    (NextResponse.json as jest.Mock).mockImplementation((data, options) => ({
      ...data,
      status: options?.status,
    }));

    const requestBody = {
      name: 'Test User',
      email: 'test@example.com',
      password: 'password123',
    };

    const response = await POST(mockRequest(requestBody));

    expect(response).toEqual({
      error: 'Error creating user',
      status: 500,
    });
  });

  it('should handle invalid input', async () => {
    const response = await POST(mockRequest({}));

    expect(response).toEqual({
      error: 'Error creating user',
      status: 500,
    });
  });
}); 