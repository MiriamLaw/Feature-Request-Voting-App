import { NextResponse } from 'next/server'
import { PATCH } from '@/app/api/features/[featureId]/status/route'
import { getServerSession } from 'next-auth/next'
import { prisma } from '@/lib/prisma'
import { isAdmin } from '@/lib/auth'

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
      update: jest.fn(),
    },
  },
}))

// Mock auth
jest.mock('@/lib/auth', () => ({
  isAdmin: jest.fn(),
}))

describe('Feature Status API', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('PATCH /api/features/[featureId]/status', () => {
    it('should update feature status when admin', async () => {
      const mockFeatureId = 'feature123'
      const mockFeature = {
        id: mockFeatureId,
        title: 'Test Feature',
        status: 'PLANNED',
      }

      ;(getServerSession as jest.Mock).mockResolvedValue({
        user: { email: 'admin@example.com' },
      })
      ;(isAdmin as jest.Mock).mockReturnValue(true)
      ;(prisma.feature.update as jest.Mock).mockResolvedValue(mockFeature)

      const request = new Request('http://localhost:3000/api/features/feature123/status', {
        method: 'PATCH',
        body: JSON.stringify({ status: 'PLANNED' }),
      })

      const response = await PATCH(request, { params: { featureId: mockFeatureId } })
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data).toMatchObject({
        id: mockFeatureId,
        title: 'Test Feature',
        status: 'PLANNED',
      })
    })

    it('should return 401 when not authenticated', async () => {
      ;(getServerSession as jest.Mock).mockResolvedValue(null)

      const request = new Request('http://localhost:3000/api/features/feature123/status', {
        method: 'PATCH',
        body: JSON.stringify({ status: 'PLANNED' }),
      })

      const response = await PATCH(request, { params: { featureId: 'feature123' } })
      const data = await response.json()

      expect(response.status).toBe(401)
      expect(data).toMatchObject({ error: 'Unauthorized' })
    })

    it('should return 401 when not admin', async () => {
      ;(getServerSession as jest.Mock).mockResolvedValue({
        user: { email: 'user@example.com' },
      })
      ;(isAdmin as jest.Mock).mockReturnValue(false)

      const request = new Request('http://localhost:3000/api/features/feature123/status', {
        method: 'PATCH',
        body: JSON.stringify({ status: 'PLANNED' }),
      })

      const response = await PATCH(request, { params: { featureId: 'feature123' } })
      const data = await response.json()

      expect(response.status).toBe(401)
      expect(data).toMatchObject({ error: 'Unauthorized' })
    })

    it('should return 400 when status is invalid', async () => {
      ;(getServerSession as jest.Mock).mockResolvedValue({
        user: { email: 'admin@example.com' },
      })
      ;(isAdmin as jest.Mock).mockReturnValue(true)

      const request = new Request('http://localhost:3000/api/features/feature123/status', {
        method: 'PATCH',
        body: JSON.stringify({ status: 'INVALID_STATUS' }),
      })

      const response = await PATCH(request, { params: { featureId: 'feature123' } })
      const data = await response.json()

      expect(response.status).toBe(400)
      expect(data).toMatchObject({
        error: expect.stringContaining('Invalid status'),
      })
    })

    it('should handle errors gracefully', async () => {
      ;(getServerSession as jest.Mock).mockResolvedValue({
        user: { email: 'admin@example.com' },
      })
      ;(isAdmin as jest.Mock).mockReturnValue(true)
      ;(prisma.feature.update as jest.Mock).mockRejectedValue(new Error('Database error'))

      const request = new Request('http://localhost:3000/api/features/feature123/status', {
        method: 'PATCH',
        body: JSON.stringify({ status: 'PLANNED' }),
      })

      const response = await PATCH(request, { params: { featureId: 'feature123' } })
      const data = await response.json()

      expect(response.status).toBe(500)
      expect(data).toMatchObject({ error: 'Failed to update status' })
    })
  })
}) 