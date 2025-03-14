import { getServerSession } from "next-auth/next"
import { NextResponse } from "next/server"
import { authOptions } from "../auth/[...nextauth]/route"
import { prisma } from "@/lib/prisma"

export async function POST(req: Request) {
  try {
    const session = await getServerSession(authOptions)

    if (!session?.user?.id) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const json = await req.json()
    const { featureId } = json

    if (!featureId) {
      return NextResponse.json({ error: "Feature ID is required" }, { status: 400 })
    }

    // First check if the user has already voted
    const existingVote = await prisma.vote.findUnique({
      where: {
        userId_featureId: {
          userId: session.user.id,
          featureId,
        },
      },
    })

    let result;
    
    if (existingVote) {
      // Remove the vote
      await prisma.vote.delete({
        where: {
          id: existingVote.id
        }
      })
      
      // Get updated count after deletion
      const updatedFeature = await prisma.feature.findUnique({
        where: { id: featureId },
        include: {
          _count: {
            select: { votes: true }
          }
        }
      })

      result = {
        hasVoted: false,
        voteCount: updatedFeature?._count.votes ?? 0
      }
    } else {
      // Create new vote
      await prisma.vote.create({
        data: {
          userId: session.user.id,
          featureId,
        }
      })

      // Get updated count after creation
      const updatedFeature = await prisma.feature.findUnique({
        where: { id: featureId },
        include: {
          _count: {
            select: { votes: true }
          }
        }
      })

      result = {
        hasVoted: true,
        voteCount: updatedFeature?._count.votes ?? 0
      }
    }

    return NextResponse.json(result)
  } catch (error) {
    console.error("Vote error:", error)
    return NextResponse.json({ error: "Internal server error" }, { status: 500 })
  }
}

