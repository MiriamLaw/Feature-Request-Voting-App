import { getServerSession } from "next-auth/next"
import { NextResponse } from "next/server"
import { authOptions } from "@/app/api/auth/[...nextauth]/route"
import { prisma } from "@/lib/prisma"

export async function GET() {
  try {
    const session = await getServerSession(authOptions)
    const userId = session?.user?.id

    // First get all features with their vote counts
    const features = await prisma.feature.findMany({
      orderBy: {
        createdAt: 'desc', // Always show newest first
      },
      include: {
        author: {
          select: {
            name: true,
          },
        },
        votes: {
          where: userId ? {
            userId: userId
          } : undefined,
        },
        _count: {
          select: {
            votes: true
          }
        }
      },
    })

    // Transform the data
    const transformedFeatures = features.map(feature => ({
      id: feature.id,
      title: feature.title,
      description: feature.description,
      createdAt: feature.createdAt,
      author: feature.author,
      votes: feature._count.votes,
      hasVoted: feature.votes.length > 0,
    }))

    // Log each feature's details for debugging
    console.log('Features before sorting:', 
      transformedFeatures.map(f => ({
        id: f.id.slice(-4),
        title: f.title,
        votes: f.votes,
        createdAt: new Date(f.createdAt).toISOString(),
        hasVoted: f.hasVoted
    })))

    return NextResponse.json(transformedFeatures)
  } catch (error) {
    console.error('Fetch features error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch features' },
      { status: 500 }
    )
  }
}

export async function POST(req: Request) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      )
    }

    const { title, description } = await req.json()

    const feature = await prisma.feature.create({
      data: {
        title,
        description,
        authorId: session.user.id,
      },
    })

    return NextResponse.json(feature, { status: 201 })
  } catch (error) {
    console.error('Feature creation error:', error)
    return NextResponse.json(
      { error: 'Failed to create feature' },
      { status: 500 }
    )
  }
}

