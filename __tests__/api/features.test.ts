import { NextResponse } from 'next/server'
import { GET, POST } from '@/app/api/features/route'
import { getServerSession } from 'next-auth/next'
import { prisma } from '@/lib/prisma'

// Mock next-auth/next
jest.mock('next-auth/next', () => ({
  getServerSession: jest.fn(),
}))

// Mock auth configuration
jest.mock('@/app/api/auth/[...nextauth]/route', () => ({
  authOptions: {
    adapter: {},
    session: { strategy: 'jwt' },
    pages: { signIn: '/login' },
    providers: [],
    callbacks: {},
  },
}))

// Mock prisma
jest.mock('@/lib/prisma', () => ({
  prisma: {
    feature: {
      findMany: jest.fn(),
      create: jest.fn(),
    },
  },
}))

describe('Features API', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GET /api/features', () => {
    it('should return features when user is not authenticated', async () => {
      // Mock prisma response
      const mockFeatures = [
        {
          id: '1',
          title: 'Test Feature',
          description: 'Test Description',
          createdAt: new Date(),
          author: { name: 'Test User' },
          votes: [],
          _count: { votes: 0 },
        },
      ]

      ;(prisma.feature.findMany as jest.Mock).mockResolvedValue(mockFeatures)
      ;(getServerSession as jest.Mock).mockResolvedValue(null)

      const response = await GET()
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data).toHaveLength(1)
      expect(data[0]).toMatchObject({
        id: '1',
        title: 'Test Feature',
        description: 'Test Description',
        author: { name: 'Test User' },
        votes: 0,
        hasVoted: false,
      })
    })

    it('should return features with user vote status when authenticated', async () => {
      const mockUserId = 'user123'
      const mockFeatures = [
        {
          id: '1',
          title: 'Test Feature',
          description: 'Test Description',
          createdAt: new Date(),
          author: { name: 'Test User' },
          votes: [{ userId: mockUserId }],
          _count: { votes: 1 },
        },
      ]

      ;(prisma.feature.findMany as jest.Mock).mockResolvedValue(mockFeatures)
      ;(getServerSession as jest.Mock).mockResolvedValue({
        user: { id: mockUserId },
      })

      const response = await GET()
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data).toHaveLength(1)
      expect(data[0]).toMatchObject({
        id: '1',
        title: 'Test Feature',
        description: 'Test Description',
        author: { name: 'Test User' },
        votes: 1,
        hasVoted: true,
      })
    })

    it('should handle errors gracefully', async () => {
      ;(prisma.feature.findMany as jest.Mock).mockRejectedValue(new Error('Database error'))
      ;(getServerSession as jest.Mock).mockResolvedValue(null)

      const response = await GET()
      const data = await response.json()

      expect(response.status).toBe(500)
      expect(data).toMatchObject({ error: 'Failed to fetch features' })
    })
  })

  describe('POST /api/features', () => {
    it('should create a new feature when authenticated', async () => {
      const mockUserId = 'user123'
      const mockFeature = {
        id: '1',
        title: 'New Feature',
        description: 'New Description',
        createdAt: new Date(),
        authorId: mockUserId,
      }

      ;(getServerSession as jest.Mock).mockResolvedValue({
        user: { id: mockUserId },
      })
      ;(prisma.feature.create as jest.Mock).mockResolvedValue(mockFeature)

      const request = new Request('http://localhost:3000/api/features', {
        method: 'POST',
        body: JSON.stringify({
          title: 'New Feature',
          description: 'New Description',
        }),
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(201)
      expect(data).toMatchObject({
        id: '1',
        title: 'New Feature',
        description: 'New Description',
        authorId: mockUserId,
      })
    })

    it('should return 401 when not authenticated', async () => {
      ;(getServerSession as jest.Mock).mockResolvedValue(null)

      const request = new Request('http://localhost:3000/api/features', {
        method: 'POST',
        body: JSON.stringify({
          title: 'New Feature',
          description: 'New Description',
        }),
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(401)
      expect(data).toMatchObject({ error: 'Unauthorized' })
    })

    it('should handle errors gracefully', async () => {
      ;(getServerSession as jest.Mock).mockResolvedValue({
        user: { id: 'user123' },
      })
      ;(prisma.feature.create as jest.Mock).mockRejectedValue(new Error('Database error'))

      const request = new Request('http://localhost:3000/api/features', {
        method: 'POST',
        body: JSON.stringify({
          title: 'New Feature',
          description: 'New Description',
        }),
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(500)
      expect(data).toMatchObject({ error: 'Failed to create feature' })
    })
  })
}) 