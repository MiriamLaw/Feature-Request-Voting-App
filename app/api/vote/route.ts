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
      
      result = {
        hasVoted: false
      }
    } else {
      // Create new vote
      await prisma.vote.create({
        data: {
          userId: session.user.id,
          featureId,
        }
      })

      result = {
        hasVoted: true
      }
    }

    return NextResponse.json(result)
  } catch (error) {
    console.error("Vote error:", error)
    return NextResponse.json({ error: "Internal server error" }, { status: 500 })
  }
}

