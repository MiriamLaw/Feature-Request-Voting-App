import { getServerSession } from "next-auth/next"
import { NextResponse } from "next/server"
import { authOptions } from "@/app/api/auth/[...nextauth]/route"
import { prisma } from "@/lib/prisma"

export async function GET() {
  try {
    const session = await getServerSession(authOptions)
    const userId = session?.user?.id

    const features = await prisma.feature.findMany({
      include: {
        author: {
          select: {
            name: true,
          },
        },
        votes: true,
      },
    })

    // Transform and sort the features by vote count
    const transformedFeatures = features
      .map(feature => ({
        ...feature,
        votes: feature.votes.length,
        hasVoted: userId ? feature.votes.some(vote => vote.userId === userId) : false,
      }))
      .sort((a, b) => b.votes - a.votes) // Sort by vote count, highest first

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

