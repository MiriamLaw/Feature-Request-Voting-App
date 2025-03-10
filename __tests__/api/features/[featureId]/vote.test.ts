import { NextResponse } from 'next/server'
import { POST, DELETE } from '@/app/api/features/[featureId]/vote/route'
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
    vote: {
      create: jest.fn(),
      findUnique: jest.fn(),
      delete: jest.fn(),
    },
    feature: {
      findUnique: jest.fn(),
    },
  },
}))

describe('Feature Vote API', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('POST /api/features/[featureId]/vote', () => {
    it('should create a vote when authenticated', async () => {
      const mockUserId = 'user123'
      const mockFeatureId = 'feature123'
      const mockFeature = {
        id: mockFeatureId,
        votes: [{ id: 'vote123' }],
        author: { name: 'Test User' },
      }

      ;(getServerSession as jest.Mock).mockResolvedValue({
        user: { id: mockUserId },
      })
      ;(prisma.vote.create as jest.Mock).mockResolvedValue({ id: 'vote123' })
      ;(prisma.feature.findUnique as jest.Mock).mockResolvedValue(mockFeature)

      const request = new Request('http://localhost:3000/api/features/feature123/vote', {
        method: 'POST',
      })

      const response = await POST(request, { params: { featureId: mockFeatureId } })
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data).toMatchObject({
        id: mockFeatureId,
        votes: 1,
        hasVoted: true,
      })
    })

    it('should return 401 when not authenticated', async () => {
      ;(getServerSession as jest.Mock).mockResolvedValue(null)

      const request = new Request('http://localhost:3000/api/features/feature123/vote', {
        method: 'POST',
      })

      const response = await POST(request, { params: { featureId: 'feature123' } })
      const data = await response.json()

      expect(response.status).toBe(401)
      expect(data).toMatchObject({ error: 'Unauthorized' })
    })

    it('should return 404 when feature not found', async () => {
      ;(getServerSession as jest.Mock).mockResolvedValue({
        user: { id: 'user123' },
      })
      ;(prisma.vote.create as jest.Mock).mockResolvedValue({ id: 'vote123' })
      ;(prisma.feature.findUnique as jest.Mock).mockResolvedValue(null)

      const request = new Request('http://localhost:3000/api/features/feature123/vote', {
        method: 'POST',
      })

      const response = await POST(request, { params: { featureId: 'feature123' } })
      const data = await response.json()

      expect(response.status).toBe(404)
      expect(data).toMatchObject({ error: 'Feature not found' })
    })

    it('should handle errors gracefully', async () => {
      ;(getServerSession as jest.Mock).mockResolvedValue({
        user: { id: 'user123' },
      })
      ;(prisma.vote.create as jest.Mock).mockRejectedValue(new Error('Database error'))

      const request = new Request('http://localhost:3000/api/features/feature123/vote', {
        method: 'POST',
      })

      const response = await POST(request, { params: { featureId: 'feature123' } })
      const data = await response.json()

      expect(response.status).toBe(500)
      expect(data).toMatchObject({ error: 'Failed to vote' })
    })
  })

  describe('DELETE /api/features/[featureId]/vote', () => {
    it('should delete a vote when authenticated', async () => {
      const mockUserId = 'user123'
      const mockFeatureId = 'feature123'

      ;(getServerSession as jest.Mock).mockResolvedValue({
        user: { id: mockUserId },
      })
      ;(prisma.vote.findUnique as jest.Mock).mockResolvedValue({
        id: 'vote123',
        userId: mockUserId,
        featureId: mockFeatureId,
      })
      ;(prisma.vote.delete as jest.Mock).mockResolvedValue({ id: 'vote123' })

      const request = new Request('http://localhost:3000/api/features/feature123/vote', {
        method: 'DELETE',
      })

      const response = await DELETE(request, { params: { featureId: mockFeatureId } })
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data).toMatchObject({ message: 'Vote removed' })
    })

    it('should return 401 when not authenticated', async () => {
      ;(getServerSession as jest.Mock).mockResolvedValue(null)

      const request = new Request('http://localhost:3000/api/features/feature123/vote', {
        method: 'DELETE',
      })

      const response = await DELETE(request, { params: { featureId: 'feature123' } })
      const data = await response.json()

      expect(response.status).toBe(401)
      expect(data).toMatchObject({ error: 'Unauthorized' })
    })

    it('should return 404 when vote not found', async () => {
      ;(getServerSession as jest.Mock).mockResolvedValue({
        user: { id: 'user123' },
      })
      ;(prisma.vote.findUnique as jest.Mock).mockResolvedValue(null)

      const request = new Request('http://localhost:3000/api/features/feature123/vote', {
        method: 'DELETE',
      })

      const response = await DELETE(request, { params: { featureId: 'feature123' } })
      const data = await response.json()

      expect(response.status).toBe(404)
      expect(data).toMatchObject({ error: 'Vote not found' })
    })

    it('should handle errors gracefully', async () => {
      ;(getServerSession as jest.Mock).mockResolvedValue({
        user: { id: 'user123' },
      })
      ;(prisma.vote.findUnique as jest.Mock).mockResolvedValue({
        id: 'vote123',
        userId: 'user123',
        featureId: 'feature123',
      })
      ;(prisma.vote.delete as jest.Mock).mockRejectedValue(new Error('Database error'))

      const request = new Request('http://localhost:3000/api/features/feature123/vote', {
        method: 'DELETE',
      })

      const response = await DELETE(request, { params: { featureId: 'feature123' } })
      const data = await response.json()

      expect(response.status).toBe(500)
      expect(data).toMatchObject({ error: 'Failed to remove vote' })
    })
  })
}) 