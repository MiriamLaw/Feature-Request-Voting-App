import { getServerSession } from "next-auth/next"
import { NextResponse } from "next/server"
import { authOptions } from "../auth/[...nextauth]/route"
import { prisma } from "@/lib/prisma"

export async function POST(req: Request) {
  try {
    const session = await getServerSession(authOptions)

    if (!session) {
      return new NextResponse("Unauthorized", { status: 401 })
    }

    const json = await req.json()
    const { featureId } = json

    const existingVote = await prisma.vote.findUnique({
      where: {
        userId_featureId: {
          userId: session.user.id,
          featureId,
        },
      },
    })

    if (existingVote) {
      await prisma.vote.delete({
        where: {
          id: existingVote.id,
        },
      })
      return NextResponse.json({ message: "Vote removed" })
    }

    const vote = await prisma.vote.create({
      data: {
        userId: session.user.id,
        featureId,
      },
    })

    return NextResponse.json(vote)
  } catch (error) {
    console.error(error)
    return new NextResponse("Internal Error", { status: 500 })
  }
}

